package io.github.commandantx.mintcraft.bridge;
import dan200.computercraft.api.lua.IComputerSystem;
import dan200.computercraft.api.lua.ILuaAPI;
import dan200.computercraft.api.lua.LuaFunction;
import dev.ryanhcode.sable.Sable;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import java.util.LinkedHashMap;
import java.util.Map;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import org.joml.Vector3d;
/** Actual loaded world blocks, never the vehicle plot as terrain. */
public final class TerrainApi implements ILuaAPI {
    private static final FeedbackBudget BUDGET=new FeedbackBudget(16384);
    private String sourceClockId=java.util.UUID.randomUUID().toString();
    private String lastDimension;
    private long lastGameTick=Long.MIN_VALUE,lastServerTick=Long.MIN_VALUE;
    private final IComputerSystem computer;
    private long lastTick=Long.MIN_VALUE, lastContextTick=Long.MIN_VALUE;
    private static final FeedbackBudget CONTEXT_BUDGET=new FeedbackBudget(32);
    public TerrainApi(IComputerSystem computer) { this.computer=computer; }
    @Override public String[] getNames() { return new String[]{"mintcraft_terrain"}; }
    @LuaFunction public final Map<String,Object> status() {
        return Map.of("schema",1,"version","0.4.0","readOnly",true,"computerId",computer.getID(),"allowed",TerrainPolicy.allowed(computer.getID()),
            "policy","server opt-in and explicit computer allowlist","scope","loaded local static world blocks; dynamic coverage unavailable");
    }
    @LuaFunction(mainThread=true)
    public final Map<String,Object> context() {
        if(!TerrainPolicy.allowed(computer.getID())) return unavailable("FORBIDDEN","Server terrain reads disabled or computer ID not allowed");
        try {
            var containing=Sable.HELPER.getContaining(computer.getLevel(),computer.getPosition());
            if(!(containing instanceof ServerSubLevel ship)||ship.isRemoved()||!(ship.getLevel() instanceof ServerLevel level))
                return unavailable("NOT_ON_SUBLEVEL","Actual parent server world unavailable");
            long tick=level.getServer().getTickCount();
            if(lastContextTick!=Long.MIN_VALUE&&tick>=lastContextTick&&tick-lastContextTick<5||!CONTEXT_BUDGET.claim(tick,1))
                return unavailable("BUSY","Terrain context observation budget exhausted");
            lastContextTick=tick;
            var p=computer.getPosition();
            var world=ship.logicalPose().transformPosition(new Vector3d(p.getX()+.5,p.getY()+.5,p.getZ()+.5));
            var r=new LinkedHashMap<String,Object>();
            r.put("schema",1); r.put("ok",true); r.put("readOnly",true); r.put("scope","actual-parent-world-context");
            r.put("namespace",level.dimension().location().toString()); r.put("vehicleId",ship.getUniqueId().toString());
            r.put("frame","world"); r.put("unit","block"); r.put("position",BridgeMath.vector(world.x,world.y,world.z));
            r.put("clock","minecraft_game_tick"); r.put("clockId",clock(level)); r.put("observedAtGameTick",level.getGameTime()); r.put("serverTick",tick);
            r.put("minimumY",level.getMinBuildHeight()); r.put("maximumY",level.getMaxBuildHeight()); r.put("computerId",computer.getID());
            return r;
        } catch(RuntimeException|LinkageError e) { return unavailable("TERRAIN_CONTEXT_FAILED",e.getClass().getSimpleName()); }
    }
    @LuaFunction(mainThread=true)
    public final Map<String,Object> terrainPage(String vehicle,String namespace,int x,int y,int z) {
        if(!TerrainPolicy.allowed(computer.getID())) return unavailable("FORBIDDEN","Server terrain reads disabled or computer ID not allowed");
        try {
            var containing=Sable.HELPER.getContaining(computer.getLevel(),computer.getPosition());
            if(!(containing instanceof ServerSubLevel ship)||ship.isRemoved()||!ship.getUniqueId().toString().equals(vehicle)) return unavailable("VEHICLE_CHANGED","Query must belong to the containing sublevel");
            if(!(ship.getLevel() instanceof ServerLevel level)) return unavailable("WORLD_UNAVAILABLE","Parent server world unavailable");
            String dimension=level.dimension().location().toString();
            if(!dimension.equals(namespace)) return unavailable("DIMENSION_CHANGED","Actual parent world differs from requested dimension");
            var p=computer.getPosition();
            var world=ship.logicalPose().transformPosition(new Vector3d(p.getX()+.5,p.getY()+.5,p.getZ()+.5));
            TerrainSelection.validate(x,y,z,world.x,world.y,world.z,level.getMinBuildHeight(),level.getMaxBuildHeight());
            long tick=level.getServer().getTickCount();
            if(lastTick!=Long.MIN_VALUE&&tick>=lastTick&&tick-lastTick<5) return unavailable("BUSY","One terrain page per five server ticks per computer");
            lastTick=tick;
            if(!BUDGET.claim(tick,4096)) return unavailable("BUSY","Server-wide terrain block budget exhausted");
            var chunk=level.getChunkSource().getChunkNow(x>>4,z>>4);
            if(chunk==null) return unavailable("UNLOADED","World chunk not loaded; no chunk requested");
            int[] cells=new int[4096]; int occupied=0;
            for(int i=0;i<4096;i++) {
                var state=chunk.getBlockState(new BlockPos(x+(i&15),y+(i>>8),z+((i>>4)&15)));
                // Conservative full cubes; collision shapes could inspect neighbours.
                if(!state.isAir()) { cells[i]=1; occupied++; }
            }
            var r=new LinkedHashMap<String,Object>();
            r.put("schema",1); r.put("ok",true); r.put("readOnly",true); r.put("scope","loaded-world-static-section");
            r.put("vehicleId",vehicle); r.put("namespace",dimension); r.put("frame","world"); r.put("unit","block");
            r.put("origin",BridgeMath.vector(x,y,z)); r.put("edge",16); r.put("clock","minecraft_game_tick"); r.put("clockId",clock(level));
            r.put("observedAtGameTick",level.getGameTime()); r.put("serverTick",tick); r.put("complete",true);
            r.put("encoding","sparse-runs-start:length:value"); r.put("runs",VoxelCodec.encode(cells)); r.put("occupied",occupied);
            r.put("classification","air only is free; all non-air conservatively occupied"); r.put("dynamicCoverage",false);
            r.put("limits",Map.of("radius",128,"edge",16,"minimumIntervalTicks",5,"globalBlocksPerTick",16384)); return r;
        } catch(IllegalArgumentException e) { return unavailable("INVALID_QUERY",e.getMessage()); }
        catch(RuntimeException|LinkageError e) { return unavailable("TERRAIN_READ_FAILED",e.getClass().getSimpleName()); }
    }
    private String clock(ServerLevel level) {
        String namespace=level.dimension().location().toString();
        long game=level.getGameTime(),server=level.getServer().getTickCount();
        if(lastDimension!=null&&(!namespace.equals(lastDimension)||game<lastGameTick||server<lastServerTick)) sourceClockId=java.util.UUID.randomUUID().toString();
        lastDimension=namespace; lastGameTick=game; lastServerTick=server; return sourceClockId;
    }
    private static Map<String,Object> unavailable(String code,String reason) {
        return Map.of("schema",1,"ok",false,"readOnly",true,"scope","loaded-world-static-section","code",code,"reason",reason);
    }
}
