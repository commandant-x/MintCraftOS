package io.github.commandantx.mintcraft.bridge;

import com.simibubi.create.content.redstone.link.LinkBehaviour;
import com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity;
import com.simibubi.create.foundation.blockEntity.behaviour.BlockEntityBehaviour;
import dan200.computercraft.api.lua.IComputerSystem;
import dan200.computercraft.api.lua.ILuaAPI;
import dan200.computercraft.api.lua.LuaFunction;
import dev.eriksonn.aeronautics.content.blocks.propeller.bearing.gyroscopic_propeller_bearing.GyroscopicPropellerBearingBlockEntity;
import dev.eriksonn.aeronautics.content.blocks.propeller.bearing.propeller_bearing.PropellerBearingBlockEntity;
import dev.eriksonn.aeronautics.content.blocks.propeller.small.BasePropellerBlockEntity;
import dev.eriksonn.aeronautics.content.blocks.hot_air.hot_air_burner.HotAirBurnerBlockEntity;
import dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon;
import dev.ryanhcode.sable.Sable;
import dev.ryanhcode.sable.api.block.propeller.BlockEntityPropeller;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.ryanhcode.sable.sublevel.plot.PlotChunkHolder;
import net.minecraft.core.BlockPos;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.entity.BlockEntity;
import org.joml.Matrix3dc;
import org.joml.Vector3dc;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;

/** Read-only server API. Never calls assembly, setters, chunk loading or physics mutation. */
public final class VehicleApi implements ILuaAPI {
    private static final int MAX_CHUNKS = 128, MAX_BLOCK_ENTITIES = 4096, MAX_ACTUATORS = 256, MAX_LINKS = 256;
    private static final Map<ServerSubLevel, Cached> CACHE = new WeakHashMap<>();
    private record Cached(long tick, Map<String, Object> data) {}
    private final IComputerSystem computer;
    private HullScan hull;
    private long lastHullTick = Long.MIN_VALUE;
    private record Section(net.minecraft.world.level.chunk.LevelChunkSection data, int x, int y, int z) {}
    private record HullScan(String token, String vehicle, long started, List<Section> sections,
                            boolean coverage, Map<String,Object> bounds) {}

    /** One loaded 16^3 section per call. No world/chunk loads and no output writes. */
    @LuaFunction(mainThread = true)
    public final Map<String,Object> geometryPage(int page, String token) {
        try {
            var containing = Sable.HELPER.getContaining(computer.getLevel(),computer.getPosition());
            if (!(containing instanceof ServerSubLevel ship) || ship.isRemoved()) return unavailable("NOT_ON_SUBLEVEL","Computer is not on a sublevel");
            long tick=computer.getLevel().getGameTime();
            if (tick==lastHullTick) return unavailable("BUSY","One geometry page per game tick");
            lastHullTick=tick;
            if(page==0 && token.isEmpty()) hull=beginHull(ship,tick);
            if(hull==null || !hull.vehicle.equals(ship.getUniqueId().toString()) || page<0 || page>=Math.max(1,hull.sections.size()) ||
                (page!=0 || !token.isEmpty()) && !hull.token.equals(token) || tick<hull.started || tick-hull.started>24000)
                return unavailable("SCAN_CHANGED","Restart geometry survey");
            var current=beginHull(ship,tick);
            if(current.sections.size()!=hull.sections.size() || !current.bounds.equals(hull.bounds) || current.coverage!=hull.coverage)
                return unavailable("SCAN_CHANGED","Loaded geometry changed; restart survey");
            for(int i=0;i<current.sections.size();i++) if(!current.sections.get(i).equals(hull.sections.get(i)))
                return unavailable("SCAN_CHANGED","Section layout changed; restart survey");
            var result=new LinkedHashMap<String,Object>();
            result.put("schema",1); result.put("ok",true); result.put("readOnly",true);
            result.put("vehicleId",hull.vehicle); result.put("token",hull.token); result.put("page",page);
            result.put("pages",Math.max(1,hull.sections.size())); result.put("frame","body_plot");
            result.put("units","block"); result.put("startedTick",hull.started); result.put("observedTick",tick);
            result.put("coverageComplete",hull.coverage); result.put("nestedSublevelsIncluded",false);
            result.put("bounds",hull.bounds); result.put("atomic",false);
            var palette=new ArrayList<Map<String,String>>();
            var indices=new LinkedHashMap<net.minecraft.world.level.block.state.BlockState,Integer>();
            int[] cells=new int[4096];
            if(!hull.sections.isEmpty()) {
                Section section=hull.sections.get(page);
                result.put("origin",BridgeMath.vector(section.x,section.y,section.z));
                for(int n=0;n<4096;n++) {
                    var state=section.data.getBlockState(n&15,n>>8,(n>>4)&15);
                    if(!state.isAir()) {
                        Integer id=indices.get(state);
                        if(id==null) {
                            id=indices.size()+1; indices.put(state,id);
                            palette.add(Map.of("block",BuiltInRegistries.BLOCK.getKey(state.getBlock()).toString(),"state",state.toString()));
                        }
                        cells[n]=id;
                    }
                }
            } else result.put("origin",BridgeMath.vector(0,0,0));
            result.put("palette",palette); result.put("runs",VoxelCodec.encode(cells));
            return result;
        } catch(RuntimeException | LinkageError error) { return unavailable("HULL_READ_FAILED",error.getClass().getSimpleName()); }
    }
    private static HullScan beginHull(ServerSubLevel ship,long tick) {
        var origin=ship.getPlot().getCenterBlock();
        var bounds=ship.getPlot().getBoundingBox();
        var sections=new ArrayList<Section>();
        var loaded=new java.util.HashSet<Long>();
        int count=0; boolean coverage=true;
        for(PlotChunkHolder holder:ship.getPlot().getLoadedChunks()) {
            if(++count>MAX_CHUNKS) { coverage=false; break; }
            var chunk=holder.getChunk(); var pos=chunk.getPos(); loaded.add(pos.toLong());
            var data=chunk.getSections();
            for(int i=0;i<data.length;i++) if(!data[i].hasOnlyAir()) {
                if(sections.size()>=1024) { coverage=false; break; }
                sections.add(new Section(data[i],pos.getMinBlockX()-origin.getX(),
                    chunk.getSectionYFromSectionIndex(i)*16-origin.getY(),pos.getMinBlockZ()-origin.getZ()));
            }
        }
        long needed=((long)(bounds.maxX()>>4)-(bounds.minX()>>4)+1)*((long)(bounds.maxZ()>>4)-(bounds.minZ()>>4)+1);
        if(needed>MAX_CHUNKS || needed<0) coverage=false;
        else for(int x=bounds.minX()>>4;x<=bounds.maxX()>>4;x++) for(int z=bounds.minZ()>>4;z<=bounds.maxZ()>>4;z++)
            if(!loaded.contains(net.minecraft.world.level.ChunkPos.asLong(x,z))) coverage=false;
        sections.sort(Comparator.comparingInt(Section::x).thenComparingInt(Section::y).thenComparingInt(Section::z));
        var box=new LinkedHashMap<String,Object>();
        box.put("min",BridgeMath.vector(bounds.minX()-origin.getX(),bounds.minY()-origin.getY(),bounds.minZ()-origin.getZ()));
        box.put("max",BridgeMath.vector(bounds.maxX()-origin.getX(),bounds.maxY()-origin.getY(),bounds.maxZ()-origin.getZ()));
        return new HullScan(java.util.UUID.randomUUID().toString(),ship.getUniqueId().toString(),tick,List.copyOf(sections),coverage,box);
    }

    public VehicleApi(IComputerSystem computer) { this.computer = computer; }
    @Override public String[] getNames() { return new String[]{"mintcraft_vehicle"}; }

    @LuaFunction public final Map<String, Object> status() {
        return Map.of("schema", 1, "version", "0.2.2", "readOnly", true,
            "scope", "containing sublevel; loaded blocks and block entities", "controlWrites", false);
    }

    @LuaFunction(mainThread = true)
    public final Map<String, Object> snapshot() {
        try {
            var containing = Sable.HELPER.getContaining(computer.getLevel(), computer.getPosition());
            if (!(containing instanceof ServerSubLevel ship) || ship.isRemoved())
                return unavailable("NOT_ON_SUBLEVEL", "Computer is not on a server sublevel");
            long tick = computer.getLevel().getGameTime();
            Cached old = CACHE.get(ship);
            if (old == null || tick < old.tick || tick - old.tick >= 20) {
                old = new Cached(tick, read(ship, tick));
                CACHE.put(ship, old);
            }
            var result = new LinkedHashMap<>(old.data);
            result.put("ageTicks", tick - old.tick);
            return result;
        } catch (RuntimeException | LinkageError error) {
            return unavailable("BRIDGE_READ_FAILED", error.getClass().getSimpleName());
        }
    }

    private static Map<String, Object> unavailable(String code, String message) {
        return Map.of("schema", 1, "ok", false, "readOnly", true, "code", code, "error", message);
    }
    private static Map<String, Double> vec(Vector3dc v) { return BridgeMath.vector(v.x(), v.y(), v.z()); }
    private static Map<String, Double> relative(Vector3dc v, BlockPos origin) {
        return BridgeMath.relative(v.x(), v.y(), v.z(), origin.getX(), origin.getY(), origin.getZ());
    }
    private static Map<String, Double> position(BlockPos pos, BlockPos origin) {
        return BridgeMath.relative(pos.getX()+0.5, pos.getY()+0.5, pos.getZ()+0.5,
            origin.getX(), origin.getY(), origin.getZ());
    }
    private static String id(ServerSubLevel ship, BlockPos pos, BlockPos origin) {
        return ship.getUniqueId() + ":" + (pos.getX()-origin.getX()) + ":" + (pos.getY()-origin.getY()) + ":" + (pos.getZ()-origin.getZ());
    }
    private static List<List<Double>> matrix(Matrix3dc m) {
        List<List<Double>> result = new ArrayList<>();
        for (int row=0; row<3; row++) {
            List<Double> values = new ArrayList<>();
            for (int col=0; col<3; col++) {
                double value = m.get(col, row);
                if (!Double.isFinite(value)) throw new IllegalArgumentException("non-finite inertia");
                values.add(value);
            }
            result.add(List.copyOf(values));
        }
        return List.copyOf(result);
    }

    private static Map<String, Object> read(ServerSubLevel ship, long tick) {
        var result = new LinkedHashMap<String, Object>();
        var errors = new ArrayList<String>();
        var actuators = new ArrayList<Map<String, Object>>();
        var burners = new ArrayList<Map<String, Object>>();
        var links = new ArrayList<Map<String, Object>>();
        BlockPos origin = ship.getPlot().getCenterBlock();
        result.put("schema", 1); result.put("ok", true); result.put("readOnly", true);
        result.put("bridgeVersion", "0.2.2"); result.put("features", Map.of("burners",true,"hullPages",true));
        result.put("vehicleId", ship.getUniqueId().toString()); result.put("name", ship.getName());
        result.put("observedAtGameTick", tick); result.put("revision", tick);
        result.put("frame", "body_plot");
        result.put("originPlot", BridgeMath.vector(origin.getX(), origin.getY(), origin.getZ()));
        result.put("axes", "+X/+Y/+Z of the unrotated Sable plot; vehicle forward is not inferred");
        result.put("units", Map.of("position", "block", "mass", "sable_mass", "force", "pixel_newton", "inertia", "sable_mass*block^2"));
        try {
            var mass = ship.getMassTracker();
            if (!mass.isInvalid() && mass.getCenterOfMass() != null && Double.isFinite(mass.getMass()) && mass.getMass()>0) {
                result.put("mass", mass.getMass());
                result.put("centerOfMass", relative(mass.getCenterOfMass(), origin));
                result.put("inertia", matrix(mass.getInertiaTensor()));
            } else errors.add("MASS_UNAVAILABLE");
        } catch (RuntimeException error) { errors.add("MASS_READ_FAILED"); }
        int chunks = 0, visited = 0;
        boolean complete = true;
        scan: for (PlotChunkHolder holder : ship.getPlot().getLoadedChunks()) {
            if (++chunks > MAX_CHUNKS) { complete = false; break; }
            for (BlockEntity entity : holder.getChunk().getBlockEntities().values()) {
                if (++visited > MAX_BLOCK_ENTITIES) { complete = false; break scan; }
                if (entity.isRemoved()) continue;
                try {
                    if (entity instanceof PropellerBearingBlockEntity || entity instanceof BasePropellerBlockEntity) {
                        if (actuators.size() >= MAX_ACTUATORS) { complete = false; continue; }
                        actuators.add(propeller(ship, entity, origin, result));
                    } else if (entity instanceof HotAirBurnerBlockEntity burner) {
                        if (burners.size()>=MAX_ACTUATORS) { complete=false; continue; }
                        burners.add(burner(ship,burner,origin));
                    } else if (entity instanceof RedstoneLinkBlockEntity link) {
                        if (links.size() >= MAX_LINKS) { complete = false; continue; }
                        var data = link(ship, link, origin);
                        if (data != null) links.add(data);
                    }
                } catch (RuntimeException error) {
                    complete = false;
                    if (errors.size()<64) errors.add("DEVICE_READ_FAILED:" + entity.getBlockPos().toShortString());
                }
            }
        }
        actuators.sort(Comparator.comparing(row -> (String) row.get("id")));
        links.sort(Comparator.comparing(row -> (String) row.get("id")));
        burners.sort(Comparator.comparing(row -> (String) row.get("id")));
        result.put("burners",burners);
        result.put("actuators", actuators); result.put("links", links); result.put("errors", errors);
        result.put("complete", complete); result.put("visitedBlockEntities", Math.min(visited, MAX_BLOCK_ENTITIES));
        result.put("limits", Map.of("chunks", MAX_CHUNKS, "blockEntities", MAX_BLOCK_ENTITIES, "actuators", MAX_ACTUATORS, "links", MAX_LINKS));
        result.put("controlBindingsKnown", false);
        result.put("nestedSublevelsIncluded", false);
        return result;
    }

    private static Map<String, Object> propeller(ServerSubLevel ship, BlockEntity entity, BlockPos origin, Map<String, Object> root) {
        BlockEntityPropeller prop = (BlockEntityPropeller) entity;
        var direction = prop.getBlockDirection().getNormal();
        double x=direction.getX(), y=direction.getY(), z=direction.getZ();
        if (entity instanceof GyroscopicPropellerBearingBlockEntity gyro) {
            // This is the same cached body vector used by its physics tick.
            x=gyro.thrustDirection.x; y=gyro.thrustDirection.y; z=gyro.thrustDirection.z;
        }
        double thrust = prop.getScaledThrust();
        if (!Double.isFinite(thrust)) throw new IllegalArgumentException("invalid thrust");
        var row = new LinkedHashMap<String, Object>();
        row.put("id", id(ship, entity.getBlockPos(), origin));
        row.put("block", BuiltInRegistries.BLOCK.getKey(entity.getBlockState().getBlock()).toString());
        row.put("position", position(entity.getBlockPos(), origin));
        row.put("direction", BridgeMath.vector(x,y,z)); row.put("geometrySource", "sable_physics_api");
        boolean active=prop.isActive();
        double applied=active ? thrust : 0;
        row.put("active", active); row.put("thrust", thrust);
        row.put("force", BridgeMath.vector(x*applied,y*applied,z*applied));
        if(root.get("centerOfMass") instanceof Map<?,?> center) {
            var point=position(entity.getBlockPos(),origin);
            row.put("torquePerUnitThrust", BridgeMath.torque(
                point.get("x")-((Number)center.get("x")).doubleValue(),
                point.get("y")-((Number)center.get("y")).doubleValue(),
                point.get("z")-((Number)center.get("z")).doubleValue(),x,y,z));
        }
        row.put("suggestedRole", BridgeMath.role(x,y,z)); row.put("roleConfidence", "orientation_only");
        row.put("controlBindingKnown", false);
        return row;
    }

    private static Map<String, Object> frequency(ItemStack stack) {
        var row = new LinkedHashMap<String, Object>();
        row.put("item", BuiltInRegistries.ITEM.getKey(stack.getItem()).toString());
        var color = stack.get(DataComponents.DYED_COLOR);
        if (color != null) row.put("dyedColor", color.rgb());
        return row;
    }
    private static Map<String,Object> burner(ServerSubLevel ship,HotAirBurnerBlockEntity burner,BlockPos origin) {
        var row=new LinkedHashMap<String,Object>();
        row.put("id",id(ship,burner.getBlockPos(),origin));
        row.put("block",BuiltInRegistries.BLOCK.getKey(burner.getBlockState().getBlock()).toString());
        row.put("position",position(burner.getBlockPos(),origin));
        row.put("signal",burner.getSignalStrength()); row.put("gasOutput",burner.getGasOutput());
        var balloon=burner.getBalloon();
        // ServerBalloon.isValid() tests gas amounts, not heater association.
        boolean associated=BridgeMath.balloonAssociated(balloon!=null,
            balloon==null ? 0 : balloon.getCapacity(),
            balloon!=null && balloon.getHeaters().contains(burner));
        row.put("hasBalloon",associated);
        row.put("associationSource","heater_membership");
        row.put("gasActive",balloon!=null && balloon.isValid());
        row.put("associationState",balloon==null ? "no_balloon_reference" :
            (associated ? "associated" : "invalid_capacity_or_heater_membership"));
        if(associated) {
            row.put("balloonId",id(ship,balloon.getControllerPos(),origin));
            row.put("capacity",balloon.getCapacity());
            if(balloon instanceof ServerBalloon server) {
                row.put("filledVolume",server.getTotalFilledVolume());
                row.put("targetVolume",server.getTotalTargetVolume());
                row.put("lift",server.getTotalLift());
            }
        }
        row.put("controlBindingKnown",false);
        return row;
    }
    private static Map<String, Object> link(ServerSubLevel ship, RedstoneLinkBlockEntity entity, BlockPos origin) {
        LinkBehaviour behavior = BlockEntityBehaviour.get(entity, LinkBehaviour.TYPE);
        if (behavior == null) return null;
        var row = new LinkedHashMap<String, Object>();
        row.put("id", id(ship, entity.getBlockPos(), origin)); row.put("position", position(entity.getBlockPos(), origin));
        row.put("receiver", behavior.isListening());
        var key = behavior.getNetworkKey();
        row.put("first", frequency(key.getFirst().getStack())); row.put("second", frequency(key.getSecond().getStack()));
        row.put("signal", behavior.isListening() ? entity.getReceivedSignal() : behavior.getTransmittedStrength());
        row.put("actuatorBindingKnown", false);
        return row;
    }
}
