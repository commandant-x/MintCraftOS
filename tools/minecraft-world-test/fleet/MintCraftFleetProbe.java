package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.LeverBlock;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.item.ItemStack;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.devce.rocketnautics.content.blocks.SputnikBlockEntity;
import dev.devce.websnodelib.api.*;
import dev.devce.websnodelib.api.elements.*;
import dev.eriksonn.aeronautics.content.blocks.propeller.bearing.propeller_bearing.PropellerBearingBlockEntity;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import java.nio.file.*;
import java.util.*;
@Mod("mintcraft_probe")
public class MintCraftFleetProbe {
 private boolean balanced(){return architecture.equals("quad-balanced")||architecture.equals("quad-turns");}
 private int gasReadyFrames;private double gasCommissionStart;private int ticks,release=-1;private final int endTick=Integer.getInteger("mintcraft.test.endTick",4400);private final Path root=Path.of("mintcraft-fleet-test");private ServerSubLevel ship;private SputnikBlockEntity sp;private BlockPos lever;private List<PropellerBearingBlockEntity> rotors=new ArrayList<>();private List<com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity> reverseReceivers=new ArrayList<>();private List<BlockEntity> links=new ArrayList<>();private List<String[]> rotorLinks=new ArrayList<>();private List<com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity> receivers=new ArrayList<>();private WNode controller,setup,commands;private boolean aborted;private int ackRevision;private int exportPage=1,exportTotal;
 private final String architecture=System.getProperty("mintcraft.fleet","tri");
 private final String shock=System.getProperty("mintcraft.shock","side5");private final boolean viewer=Boolean.getBoolean("mintcraft.waitForViewer");
 private UUID TARGET=UUID.fromString("b1b77b66-af45-46cf-baff-ca16d1d1ce34");
 private final String[] keys={"blue_wool","brown_wool","red_wool","lime_wool","white_wool","black_wool"};
 public MintCraftFleetProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 private List<WTextField> fields(WNode n){return n.getElements().stream().filter(x->x instanceof WTextField).map(x->(WTextField)x).toList();}
 private String output(WNode n,String name){return n.getOutputs().stream().filter(x->x.getName().equals(name)).findFirst().map(WPin::getValueAsString).orElse("?");}
 private WNode node(String suffix){return sp.graph.getNodes().stream().filter(n->n.getTitle().endsWith(suffix)).findFirst().orElseThrow();}
 private void event(String message)throws Exception{Files.writeString(root.resolve("events.tsv"),ticks+"\t"+message+"\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND);System.out.println("MINTCRAFT_TEST "+ticks+" "+message);}
 private void power(boolean on){ServerLevel l=ship.getLevel();var state=l.getBlockState(lever);if(!(state.getBlock() instanceof LeverBlock))throw new IllegalStateException("Enable lever missing");l.setBlock(lever,state.setValue(BlockStateProperties.POWERED,on),3);}

 private net.minecraft.world.level.block.state.BlockState block(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 private java.util.Set<BlockPos> built=new java.util.HashSet<>();
 private BlockPos base=new BlockPos(32,170,32);
 private void put(ServerLevel level,int x,int y,int z,net.minecraft.world.level.block.state.BlockState state){var p=base.offset(x,y,z);level.setBlock(p,state,3);built.add(p);}

 private void motor(ServerLevel level,int x,int z,net.minecraft.core.Direction requested,int index){
  var d=requested.getAxis()==net.minecraft.core.Direction.Axis.Y?net.minecraft.core.Direction.UP:net.minecraft.core.Direction.SOUTH;int y=d==net.minecraft.core.Direction.UP?2:balanced()?-5:5;
  for(int xx=Math.min(0,x-2);xx<=Math.max(0,x+1);xx++)put(level,xx,0,z,block("minecraft:oak_planks"));for(int yy=1;yy<y;yy++)put(level,x-1,yy,z,block("minecraft:oak_planks"));if(y<0)for(int yy=y+1;yy<0;yy++)put(level,x-1,yy,z,block("minecraft:oak_fence"));
  var trans=base.offset(x-1,y,z);put(level,x-1,y,z,block("simulated:analog_transmission").setValue(BlockStateProperties.AXIS,net.minecraft.core.Direction.Axis.X));put(level,x-1,y,z+1,block("create:cogwheel").setValue(BlockStateProperties.AXIS,net.minecraft.core.Direction.Axis.X));
  boolean drive=d!=net.minecraft.core.Direction.UP;if(drive)put(level,x,y,z,block("create:gearshift").setValue(BlockStateProperties.AXIS,net.minecraft.core.Direction.Axis.X));
  var motor=base.offset(x+(drive?1:0),y,z);put(level,x+(drive?1:0),y,z,block("create:creative_motor").setValue(BlockStateProperties.FACING,net.minecraft.core.Direction.WEST));((com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity)level.getBlockEntity(motor)).generatedSpeed.setValue(-256);
  put(level,x,y,z+1,block("create:gearbox").setValue(BlockStateProperties.AXIS,d==net.minecraft.core.Direction.UP?net.minecraft.core.Direction.Axis.Z:net.minecraft.core.Direction.Axis.Y));
  var bearing=base.offset(x,y,z+1).relative(d);level.setBlock(bearing,block("aeronautics:propeller_bearing").setValue(BlockStateProperties.FACING,d),3);built.add(bearing);var hub=bearing.relative(d);level.setBlock(hub,block("minecraft:oak_log"),3);built.add(hub);
  var arms=d==net.minecraft.core.Direction.UP?new net.minecraft.core.Direction[]{net.minecraft.core.Direction.NORTH,net.minecraft.core.Direction.SOUTH,net.minecraft.core.Direction.EAST,net.minecraft.core.Direction.WEST}:new net.minecraft.core.Direction[]{net.minecraft.core.Direction.UP,net.minecraft.core.Direction.DOWN,net.minecraft.core.Direction.EAST,net.minecraft.core.Direction.WEST};for(var arm:arms)for(int j=1;j<=4;j++){var pos=hub.relative(arm,j);level.setBlock(pos,block("create:white_sail"),3);built.add(pos);}
  var min=d==net.minecraft.core.Direction.UP?hub.offset(-4,0,-4):hub.offset(-4,-4,0);var max=d==net.minecraft.core.Direction.UP?hub.offset(4,0,4):hub.offset(4,4,0);level.addFreshEntity(new com.simibubi.create.content.contraptions.glue.SuperGlueEntity(level,com.simibubi.create.content.contraptions.glue.SuperGlueEntity.span(min,max)));
  String[] colors={"orange_wool","white_wool","light_blue_wool","magenta_wool","cyan_wool","yellow_wool","purple_wool","gray_wool"};
  var lp=trans.west();level.setBlock(lp,block("create:redstone_link").setValue(BlockStateProperties.FACING,net.minecraft.core.Direction.WEST).setValue(com.simibubi.create.content.redstone.link.RedstoneLinkBlock.RECEIVER,true),3);built.add(lp);frequency(level,lp,colors[index],"netherite_block");
  if(drive){var rp=base.offset(x,y+1,z);level.setBlock(rp,block("create:redstone_link").setValue(BlockStateProperties.FACING,net.minecraft.core.Direction.UP).setValue(com.simibubi.create.content.redstone.link.RedstoneLinkBlock.RECEIVER,true),3);built.add(rp);frequency(level,rp,colors[index],"copper_block");}
 }
 private void frequency(ServerLevel level,BlockPos pos,String first,String second){var be=level.getBlockEntity(pos);var tag=be.saveWithFullMetadata(level.registryAccess());tag.putBoolean("Transmitter",false);tag.put("FrequencyFirst",new ItemStack(BuiltInRegistries.ITEM.get(ResourceLocation.parse("minecraft:"+first))).save(level.registryAccess()));tag.put("FrequencyLast",new ItemStack(BuiltInRegistries.ITEM.get(ResourceLocation.parse("minecraft:"+second))).save(level.registryAccess()));be.loadWithComponents(tag,level.registryAccess());}
 private void construct(MinecraftServer server)throws Exception{
  var level=server.overworld();var container=SubLevelContainer.getContainer(level);var original=container.getSubLevel(TARGET);if(!(original instanceof ServerSubLevel old))throw new IllegalStateException("Source graph not loaded");
  net.minecraft.nbt.CompoundTag graph=null;for(var h:old.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SputnikBlockEntity s)graph=s.graph.save();if(graph==null)throw new IllegalStateException("Source graph missing");
  for(int x=-7;x<=7;x++)for(int z=(balanced()||architecture.equals("balloon-lift")?-8:-14);z<=8;z++)if(Math.abs(x)<=2||Math.abs(z)<=1)put(level,x,0,z,block("minecraft:oak_planks"));
  put(level,0,1,0,block("rocketnautics:sputnik"));
  if(architecture.equals("tri")){motor(level,-6,-5,net.minecraft.core.Direction.UP,0);motor(level,6,-5,net.minecraft.core.Direction.UP,1);motor(level,0,7,net.minecraft.core.Direction.UP,2);}
  else if(architecture.equals("quad-banks")||balanced()){motor(level,-6,-5,net.minecraft.core.Direction.UP,0);motor(level,6,-5,net.minecraft.core.Direction.UP,1);motor(level,-6,5,net.minecraft.core.Direction.UP,2);motor(level,6,5,net.minecraft.core.Direction.UP,3);motor(level,-5,balanced()?0:-14,net.minecraft.core.Direction.SOUTH,4);motor(level,5,balanced()?0:-14,net.minecraft.core.Direction.SOUTH,5);}
  else if(architecture.equals("balloon")||architecture.equals("balloon-lift")){
   put(level,0,1,0,block("aeronautics:adjustable_burner"));put(level,-1,1,0,block("rocketnautics:sputnik"));
   for(int x=-6;x<=6;x++)for(int z=-6;z<=6;z++)for(int yy=5;yy<=17;yy++)if(Math.abs(x)==6||Math.abs(z)==6||yy==17)put(level,x,yy,z,block("aeronautics:white_envelope"));
   for(int x:new int[]{-6,6})for(int z:new int[]{-6,6}){for(int xx=-6;xx<=6;xx++)put(level,xx,0,z,block("minecraft:oak_planks"));for(int yy=1;yy<5;yy++)put(level,x,yy,z,block("minecraft:oak_fence"));}
   if(!architecture.equals("balloon-lift")){motor(level,-5,-14,net.minecraft.core.Direction.SOUTH,4);motor(level,5,-14,net.minecraft.core.Direction.SOUTH,5);}
   var lp=base.offset(1,1,0);put(level,1,1,0,block("create:redstone_link").setValue(BlockStateProperties.FACING,net.minecraft.core.Direction.EAST).setValue(com.simibubi.create.content.redstone.link.RedstoneLinkBlock.RECEIVER,true));var bb=level.getBlockEntity(lp);var bt=bb.saveWithFullMetadata(level.registryAccess());bt.putBoolean("Transmitter",false);bt.put("FrequencyFirst",new ItemStack(net.minecraft.world.item.Items.RED_WOOL).save(level.registryAccess()));bt.put("FrequencyLast",new ItemStack(net.minecraft.world.item.Items.BLACK_WOOL).save(level.registryAccess()));bb.loadWithComponents(bt,level.registryAccess());
   put(level,0,1,1,block("minecraft:lever").setValue(BlockStateProperties.ATTACH_FACE,net.minecraft.world.level.block.state.properties.AttachFace.FLOOR).setValue(BlockStateProperties.POWERED,true));
  }else throw new IllegalStateException("Unknown fleet architecture "+architecture);
  // Dedicated Enable link and lever, independent of all motor frequencies.
  put(level,0,1,-2,block("create:redstone_link").setValue(BlockStateProperties.FACING,net.minecraft.core.Direction.UP));
  var eb=level.getBlockEntity(base.offset(0,1,-2));var et=eb.saveWithFullMetadata(level.registryAccess());et.putBoolean("Transmitter",true);et.put("FrequencyFirst",new ItemStack(net.minecraft.world.item.Items.DIAMOND_BLOCK).save(level.registryAccess()));et.put("FrequencyLast",new ItemStack(net.minecraft.world.item.Items.DIAMOND_BLOCK).save(level.registryAccess()));eb.loadWithComponents(et,level.registryAccess());
  put(level,0,1,-3,block("minecraft:lever").setValue(BlockStateProperties.ATTACH_FACE,net.minecraft.world.level.block.state.properties.AttachFace.FLOOR));put(level,0,0,-3,block("minecraft:oak_planks"));
  var made=dev.ryanhcode.sable.api.SubLevelAssemblyHelper.assembleBlocks(level,base,built,dev.ryanhcode.sable.companion.math.BoundingBox3i.from(built));if(made==null)throw new IllegalStateException("Assembly failed");TARGET=made.getUniqueId();SubLevelContainer.getContainer(level).addForceLoadTicket(made,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE);made.setName("MintCraft fleet "+architecture);PhysicsStaffServerHandler.get(level).toggleLock(TARGET);
  for(var h:made.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SputnikBlockEntity s){s.graph.load(graph);for(var n:s.graph.getNodes())if(n.getTitle().endsWith("-montage")){n.getElements().clear();n.getCustomData().putString("code",Files.readString(Path.of("mintcraft-generic-setup.lua")));}}
  event("BUILT "+architecture+" blocks="+built.size()+" native sublevel="+TARGET);
 }
 private void assembleRotors(MinecraftServer server)throws Exception{
  var made=(ServerSubLevel)SubLevelContainer.getContainer(server.overworld()).getSubLevel(TARGET);int n=0;for(var h:made.getPlot().getLoadedChunks())for(var be:new ArrayList<>(h.getChunk().getBlockEntities().values()))if(be instanceof PropellerBearingBlockEntity b){b.assemble();n++;}
  event("ASSEMBLED native bearings="+n);
 }
 private dev.eriksonn.aeronautics.content.blocks.hot_air.hot_air_burner.HotAirBurnerBlockEntity burner;
 private double gasPressure(){var balloon=(dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon)burner.getBalloon();var c=balloon.getCenter();var world=new org.joml.Vector3d(c.x,c.y,c.z).sub(ship.logicalPose().rotationPoint());ship.logicalPose().orientation().transform(world).add(ship.logicalPose().position());return dev.ryanhcode.sable.physics.config.dimension_physics.DimensionPhysicsData.getAirPressure(ship.getLevel(),world);}
 private String header(){String h="tick,universe_tick,x,y,z,pitch,yaw,roll,vx,vy,vz,target_y,active";for(int i=1;i<=rotors.size();i++)h+=",rpm"+i;for(int i=1;i<=rotors.size();i++)h+=",rx"+i;for(int i=1;i<=rotors.size();i++)h+=",shaft_signed"+i;for(int i=1;i<=rotors.size();i++)h+=",rotor_signed"+i;for(int i=1;i<=rotors.size();i++)h+=",reverse_rx"+i;return h+",wx,wy,wz,protection,burner_signal,gas_lift_kg,gas_volume,gas_provider_associated,forward_demand,left_demand,vertical_demand,commands_valid\n";}
 private void prepare(MinecraftServer server)throws Exception{
  for(ServerLevel level:server.getAllLevels()){var s=SubLevelContainer.getContainer(level).getSubLevel(TARGET);if(s instanceof ServerSubLevel ss){ship=ss;break;}}
  if(ship==null)throw new IllegalStateException("Target sublevel not loaded");
  for(var holder:ship.getPlot().getLoadedChunks())for(BlockEntity be:holder.getChunk().getBlockEntities().values()){
   if(be instanceof SputnikBlockEntity s)sp=s;if(be instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.hot_air_burner.HotAirBurnerBlockEntity b)burner=b;
   if(be instanceof PropellerBearingBlockEntity b)rotors.add(b);
   if(BuiltInRegistries.BLOCK_ENTITY_TYPE.getKey(be.getType()).toString().equals("create:redstone_link"))links.add(be);
  }
  if(sp==null||rotors.size()!=(architecture.equals("tri")?3:architecture.equals("balloon-lift")?0:architecture.equals("balloon")?2:6))throw new IllegalStateException("Unexpected fleet actuator count");
  for(var rotor:rotors)if(rotor.getScaledThrust()<0){com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity nearestMotor=null;double best=Double.POSITIVE_INFINITY;for(var h:ship.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity m){double dist=m.getBlockPos().distSqr(rotor.getBlockPos());if(dist<best){best=dist;nearestMotor=m;}}if(nearestMotor==null||best>25)throw new IllegalStateException("Motor association missing");nearestMotor.generatedSpeed.setValue(-(int)nearestMotor.getGeneratedSpeed());event("SOURCE_DIRECTION set for "+rotor.getBlockPos());}
  rotors.sort(Comparator.comparingInt((PropellerBearingBlockEntity b)->-b.getBlockPos().getZ()).thenComparingInt(b->b.getBlockPos().getX()));
  var center=ship.getMassTracker().getCenterOfMass();var bounds=ship.getPlot().getBoundingBox();double radius=0;
  for(int x:new int[]{bounds.minX(),bounds.maxX()})for(int y:new int[]{bounds.minY(),bounds.maxY()})for(int z:new int[]{bounds.minZ(),bounds.maxZ()})radius=Math.max(radius,center.distance(x,y,z));
  StringBuilder descriptors=new StringBuilder(),hardware=new StringBuilder("id\tx\ty\tz\tsails\tshaft_rpm\tthrust\tairflow\tfrequency\n");int id=0;Set<BlockEntity> used=new HashSet<>();
  for(var b:rotors){
   id++;var pos=b.getBlockPos();if(b.totalSailPower<1||b.totalSailPower!=Math.rint(b.totalSailPower)||Math.abs(b.getSpeed())!=256)throw new IllegalStateException("Unverified bearing model "+pos+" sails="+b.totalSailPower+" speed="+b.getSpeed());
   BlockEntity nearest=null;double distance=Double.POSITIVE_INFINITY;
   for(var link:links){var tag=link.saveWithFullMetadata(server.registryAccess());if(tag.getBoolean("Transmitter")||!tag.getCompound("FrequencyLast").getString("id").equals("minecraft:netherite_block"))continue;double d=pos.distSqr(link.getBlockPos());if(d<distance){distance=d;nearest=link;}}
   if(nearest==null||distance>25||!used.add(nearest))throw new IllegalStateException("Ambiguous actuator link mapping bearing="+pos+" nearest="+(nearest==null?"none":nearest.getBlockPos())+" distance="+distance+" links="+links.stream().map(q->q.getBlockPos()+":"+q.saveWithFullMetadata(server.registryAccess()).getBoolean("Transmitter")).toList());
   var tag=nearest.saveWithFullMetadata(server.registryAccess());String first=tag.getCompound("FrequencyFirst").getString("id"),second=tag.getCompound("FrequencyLast").getString("id");rotorLinks.add(new String[]{first,second});receivers.add((com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity)nearest);com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity reverse=null;for(var link:links){var rt=link.saveWithFullMetadata(server.registryAccess());if(!rt.getBoolean("Transmitter")&&rt.getCompound("FrequencyFirst").getString("id").equals(first)&&rt.getCompound("FrequencyLast").getString("id").equals("minecraft:copper_block"))reverse=(com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity)link;}reverseReceivers.add(reverse);
   double x=pos.getX()+.5-center.x(),y=pos.getY()+.5-center.y(),z=pos.getZ()+.5-center.z();
   if(id>1)descriptors.append('\n');descriptors.append("MCV1;").append(id).append(b.getBlockDirection().getStepY()!=0?";bearing;lift;":";bearing;drive;").append(x).append(';').append(y).append(';').append(z).append(";").append(b.getBlockDirection().getStepX()).append(";").append(b.getBlockDirection().getStepY()).append(";").append(b.getBlockDirection().getStepZ()).append(";256;").append((int)b.totalSailPower).append(";0.2;0.05;1;8;-1;1;").append(first).append(';').append(second).append(b.getBlockDirection().getStepY()==0?";"+first+";minecraft:copper_block;;;0;0.15;0;0":";;;;;0;0.15;0;1");
   hardware.append(id).append('\t').append(pos.getX()).append('\t').append(pos.getY()).append('\t').append(pos.getZ()).append('\t').append(b.totalSailPower).append('\t').append(b.getDirectionIndependentSpeed()).append('\t').append(b.getThrust()).append('\t').append(b.getAirflow()).append('\t').append(first+","+second).append('\n');
  }
  if(burner!=null){
   if(!(burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon balloon))throw new IllegalStateException("Balloon shell not recognized");
   var field=burner.getClass().getDeclaredField("hotAirAmountBehaviour");field.setAccessible(true);var setting=(com.simibubi.create.foundation.blockEntity.behaviour.scrollValue.ScrollValueBehaviour)field.get(burner);setting.setValue(balloon.getCapacity());double effectiveGasSetting=Math.min(balloon.getCapacity(),setting.value);
   double pressure=gasPressure();double gain=effectiveGasSetting*burner.getLiftingGasType().getLiftStrength()*11*pressure/15.;
   var c=balloon.getCenter();descriptors.append(descriptors.length()>0?"\n":"").append("MCV1;3;linear;lift;").append(c.x-center.x()).append(';').append(c.y-center.y()).append(';').append(c.z-center.z()).append(";0;1;0;256;1;1;0.1;").append(gain).append(";0;0;1;minecraft:red_wool;minecraft:black_wool;;;;;0;0.15;0;0");
   event("BALLOON capacity="+balloon.getCapacity()+" accepted_burner_setting="+effectiveGasSetting+" liftStrength="+burner.getLiftingGasType().getLiftStrength()+" gain_N_per_level="+gain+" mass="+ship.getMassTracker().getMass()+" filled="+balloon.getTotalFilledVolume());
   for(var h:ship.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){} // structure remains untouched
   var bounds2=ship.getPlot().getBoundingBox();for(var bp:BlockPos.betweenClosed(bounds2.minX(),bounds2.minY(),bounds2.minZ(),bounds2.maxX(),bounds2.maxY(),bounds2.maxZ()))if(ship.getLevel().getBlockState(bp).getBlock() instanceof LeverBlock && bp.getZ()>burner.getBlockPos().getZ())ship.getLevel().setBlock(bp,ship.getLevel().getBlockState(bp).setValue(BlockStateProperties.POWERED,false),3);
  }
  Files.writeString(root.resolve("flight.csv"),header());Files.writeString(root.resolve("descriptors.txt"),descriptors);Files.writeString(root.resolve("hardware.tsv"),hardware);Files.writeString(root.resolve("test-contract.json"),"{\"architecture\":\""+architecture+"\",\"steering\":\""+(architecture.equals("quad-turns")?"yaw":"lateral")+"\",\"horizontal_supported\":"+(!architecture.equals("balloon-lift"))+"}");Files.writeString(root.resolve("geometry.txt"),"mass="+ship.getMassTracker().getMass()+" COM="+center+" bounds="+bounds+" radius="+(radius+1)+" inertia="+ship.getMassTracker().getInertiaTensor()+"\n");
  for(var link:links){var t=link.saveWithFullMetadata(server.registryAccess());if(t.getBoolean("Transmitter")&&t.getCompound("FrequencyFirst").getString("id").equals("minecraft:diamond_block")&&t.getCompound("FrequencyLast").getString("id").equals("minecraft:diamond_block")){
   for(BlockPos p:BlockPos.betweenClosed(link.getBlockPos().offset(-2,-2,-2),link.getBlockPos().offset(2,2,2)))if(ship.getLevel().getBlockState(p).getBlock() instanceof LeverBlock){if(lever!=null)throw new IllegalStateException("Multiple Enable levers");lever=p.immutable();}
  }}
  if(lever==null)throw new IllegalStateException("Physical Enable lever not found");power(false);
  var enable=node("-enable");for(var e:enable.getElements())if(e instanceof WItemPicker p)p.setStack(new ItemStack(net.minecraft.world.item.Items.DIAMOND_BLOCK));
  setup=node("-montage");setup.getElements().stream().filter(e->e instanceof WSlider).map(e->(WSlider)e).findFirst().orElseThrow().setValue(architecture.startsWith("balloon")?2:5);var f=fields(setup);if(f.size()!=5)throw new IllegalStateException("Setup field contract changed");f.get(0).setValue("11");f.get(1).setValue("2");f.get(2).setValue("8");f.get(3).setValue(Double.toString(radius+1));f.get(4).setValue("4");for(var e:setup.getElements())if(e instanceof WCheckbox box)box.setChecked(true);setup.getElements().stream().filter(e->e instanceof WCheckbox).map(e->(WCheckbox)e).toList().get(3).setChecked(architecture.equals("quad-turns"));
  fields(node("-mount")).get(8).setValue(descriptors.toString());
  var keyboard=node("-keyboard");int k=0;for(var e:keyboard.getElements())if(e instanceof WItemPicker p){String item="minecraft:"+keys[k++/2];p.setStack(new ItemStack(BuiltInRegistries.ITEM.get(ResourceLocation.parse(item))));}else if(e instanceof WCheckbox box)box.setChecked(true);
  node("-operations").getElements().clear();node("-operations").getCustomData().putString("code",Files.readString(Path.of("mintcraft-operations.lua")));controller=node("-autopilot");controller.getElements().clear();controller.getCustomData().putString("code",Files.readString(Path.of("mintcraft-generic-controller.lua")));commands=node("-commands");event("PREPARED: independent shaft/link mapping, measured geometry, physical Enable OFF; original controller retained");
 }
 private void driver()throws Exception{
  long base=sp.getUniverseTime()-310;StringBuilder lua=new StringBuilder("local t=getUniverseTime()-"+base+"\nlocal a={0,0,0,0,0,0}\nlocal starts={800,1200,1600,2000,2400,2800,3200} local keys={5,6,1,2,3,4,1} for i,v in ipairs(starts) do if t>=v and t<v+60 then a[keys[i]]=15 if i==7 then a[3]=15 end end end\n");
  for(int i=0;i<6;i++)lua.append("transmitWirelessRedstone('minecraft:").append(keys[i]).append("','minecraft:").append(keys[i]).append("',a[").append(i+1).append("])\n");
  lua.append("output('Scenario tick',t)\n");var n=new WNode(ResourceLocation.parse("rocketnautics:lua_script"),"Test fixture: six key radio transmitter",20,1200);dev.devce.rocketnautics.registry.RocketNodes.setupLuaEvaluatorPublic(n);n.getCustomData().putString("code",lua.toString());sp.graph.addNode(n);event("DRIVER: synthetic six-key radio; no actuator outputs; scenario epoch="+base);
 }
 private void tick(ServerTickEvent.Post event){
  MinecraftServer server=event.getServer();ticks++;
  if(viewer && ticks==300 && server.getPlayerList().getPlayers().stream().noneMatch(p->p.getGameProfile().getName().equals("MintObserver")&&p.tickCount>200)){ticks--;return;}
  if(ship!=null)for(var player:server.getPlayerList().getPlayers())if(player.getGameProfile().getName().equals("MintObserver")){
   player.setGameMode(net.minecraft.world.level.GameType.SPECTATOR);
   if(ticks%10==0){var pos=ship.logicalPose().position();player.teleportTo(ship.getLevel(),pos.x()+22,pos.y()+15,pos.z()+24,137.5f,27f);}
  }
  try {
   if(ticks==300&&architecture.equals("balloon-lift")&&Double.parseDouble(output(controller,"Active"))==1){if(!(burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon)){gasReadyFrames=0;ticks--;return;}double supported=((dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon)burner.getBalloon()).getTotalLift()*gasPressure();if(Math.abs(supported-ship.getMassTracker().getMass())<=ship.getMassTracker().getMass()*.05)gasReadyFrames++;else gasReadyFrames=0;if(gasReadyFrames<20){if(sp.getUniverseTime()%100==0)event("GAS_WARMUP supported_kg="+supported+" measured_mass="+ship.getMassTracker().getMass());ticks--;return;}event("GAS_READY 20 fresh observations within five percent of measured weight");}
   Files.createDirectories(root);if(ticks==20){server.getCommands().performPrefixedCommand(server.createCommandSourceStack(),"forceload add -96 -32 96 224");server.getCommands().performPrefixedCommand(server.createCommandSourceStack(),"time set noon");server.getCommands().performPrefixedCommand(server.createCommandSourceStack(),"weather clear");}
   if(ticks==40)construct(server);if(ticks==80)assembleRotors(server);if(ticks==120)prepare(server);
   if(sp!=null){
    if(ticks==160){if(fields(node("-operations")).size()!=5||node("-operations").getElements().size()!=18||fields(controller).size()!=1)throw new IllegalStateException("Stale UI elements after source replacement");Files.writeString(root.resolve("configured-graph.snbt"),sp.graph.save().toString());event("STATUS "+output(controller,"Status"));}
    if(ticks>=140&&ticks<=300&&ticks%20==0)for(int i=0;i<rotors.size();i++){var rotor=rotors.get(i);var trans=receivers.get(i).getBlockPos().east();event("SHAFT "+(i+1)+" input="+rotor.getSpeed()+" actual="+rotor.getDirectionIndependentSpeed()+" rx="+receivers.get(i).getReceivedSignal()+" electrical="+ship.getLevel().getBestNeighborSignal(trans));}
    if(ticks==140)event("ENABLE_AUDIT physical="+ship.getLevel().getBlockState(lever)+" graph="+output(node("-enable"),"Enable"));if(ticks==140){StringBuilder lua=new StringBuilder();if(burner!=null){gasCommissionStart=-1;lua.append("transmitWirelessRedstone('minecraft:red_wool','minecraft:black_wool',10)\n");}for(var pair:rotorLinks)lua.append("transmitWirelessRedstone('").append(pair[0]).append("','").append(pair[1]).append("',10)\n");var n=new WNode(ResourceLocation.parse("rocketnautics:lua_script"),"Commissioning only, pilot OFF",20,1500);dev.devce.rocketnautics.registry.RocketNodes.setupLuaEvaluatorPublic(n);n.getCustomData().putString("code",lua.toString());sp.graph.addNode(n);event("COMMISSION signal=10 expected=80RPM, pilot OFF");}
    if(ticks>=145&&ticks<195&&gasCommissionStart<0&&burner!=null&&burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon initialGas){gasCommissionStart=initialGas.getTotalFilledVolume();event("GAS_COMMISSION_START volume="+gasCommissionStart);}
    if(ticks==200){if(burner!=null){if(!(burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon)||gasCommissionStart<0)throw new IllegalStateException("Gas provider association missing during commissioning");double volume=((dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon)burner.getBalloon()).getTotalFilledVolume();if(burner.getSignalStrength()!=10||volume<=gasCommissionStart)throw new IllegalStateException("Gas commissioning failed");event("GAS_COMMISSION_PASS signal=10 volume="+volume+" previous="+gasCommissionStart);}for(var rotor:rotors)if(Math.abs(Math.abs(rotor.getSpeed())-80)>1||Math.abs(Math.abs(rotor.getDirectionIndependentSpeed())-80)>10||rotor.getScaledThrust()<=0)throw new IllegalStateException("Commissioning failed bearing="+rotor.getBlockPos()+" input="+rotor.getSpeed()+" actual="+rotor.getDirectionIndependentSpeed());for(var n:new ArrayList<>(sp.graph.getNodes()))if(n.getTitle().startsWith("Commissioning only"))sp.graph.removeNode(n);event("COMMISSION_PASS: each shaft observed at 80RPM, temporary writer removed before arming");power(true);}
    if(ticks==300){event("WARMUP "+output(controller,"Status"));if(Double.parseDouble(output(controller,"Active"))!=1)throw new IllegalStateException("Controller not armed: "+output(controller,"Status"));if(!rotors.isEmpty()&&rotors.stream().allMatch(r->Math.abs(r.getDirectionIndependentSpeed())>250))throw new IllegalStateException("Commissioning: no shaft slowdown observed");power(false);}
    if(ticks==310){driver();power(true);}
    if(ticks==320){if(Double.parseDouble(output(controller,"Active"))!=1)throw new IllegalStateException("Controller not rearmed: "+output(controller,"Status"));var staff=PhysicsStaffServerHandler.get(ship.getLevel());if(!staff.isLocked(ship))throw new IllegalStateException("Expected locked test setup");staff.removeLock(ship);release=ticks;event("RELEASE: fixture lock removed, physical flight begins");}
    if(false && ticks>=1300 && (ticks-1300)%420==0 && output(node("-operations"),"Stop horizontal").equals("1.0")){
     fields(node("-operations")).get(3).setValue("MCREC1;"+(++ackRevision)+";ACK");event("ACK_REQUEST after settling; server decides stability");
    }
    if(ticks==3600){
     org.joml.Vector3d dv=new org.joml.Vector3d(),dw=new org.joml.Vector3d();
     switch(shock){case "side5"->dv.set(5,0,0);case "side12"->dv.set(12,0,0);case "down8"->dv.set(0,-8,0);case "up8"->dv.set(0,8,0);case "roll2"->dw.set(0,0,2);case "pitch2"->dw.set(2,0,0);case "combined"->{dv.set(7,-6,3);dw.set(1.5,0,1.5);}case "inversion"->dw.set(0,0,6);default->throw new IllegalStateException("Unknown shock "+shock);}
     var linear=dv.mul(ship.getMassTracker().getMass(),new org.joml.Vector3d());
     var angular=ship.getMassTracker().getInertiaTensor().transform(dw,new org.joml.Vector3d());ship.logicalPose().orientation().transform(angular);
     var handle=dev.ryanhcode.sable.api.physics.handle.RigidBodyHandle.of(ship);event("SHOCK "+shock+" requested_dv="+dv+" requested_body_dw="+dw+" impulse="+linear+" angular_impulse="+angular+" before_v="+handle.getLinearVelocity()+" before_w="+handle.getAngularVelocity());
     handle.applyLinearAndAngularImpulse(linear,angular);
    }
    if(ticks>=120){
     var v=sp.getVelocityVector();StringBuilder row=new StringBuilder().append(ticks).append(',').append(sp.getUniverseTime()).append(',').append(sp.getX()).append(',').append(sp.getY()).append(',').append(sp.getZ()).append(',').append(sp.getPitch()).append(',').append(sp.getYaw()).append(',').append(sp.getRoll()).append(',').append(v.x).append(',').append(v.y).append(',').append(v.z).append(',').append(output(controller,"Target altitude")).append(',').append(output(controller,"Active"));
     for(var rotor:rotors)row.append(',').append(Math.abs(rotor.getDirectionIndependentSpeed()));for(var rx:receivers)row.append(',').append(rx.getReceivedSignal());for(var rotor:rotors)row.append(',').append(rotor.getSpeed());for(var rotor:rotors)row.append(',').append(rotor.getDirectionIndependentSpeed());for(var rx:reverseReceivers)row.append(',').append(rx==null?0:rx.getReceivedSignal());var angularObserved=sp.getAngularVelocity();row.append(',').append(angularObserved.x).append(',').append(angularObserved.y).append(',').append(angularObserved.z).append(',').append(output(node("-operations"),"Stop horizontal"));row.append(',').append(burner==null?0:burner.getSignalStrength()).append(',').append(burner!=null&&burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon b?b.getTotalLift():0).append(',').append(burner!=null&&burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon b?b.getTotalFilledVolume():0);row.append(',').append(burner!=null&&burner.getBalloon()!=null?1:0).append(',').append(output(node("-keyboard"),"Forward demand")).append(',').append(output(node("-keyboard"),"Left demand")).append(',').append(output(node("-keyboard"),"Vertical demand")).append(',').append(output(node("-keyboard"),"Commands valid"));row.append('\n');Files.writeString(root.resolve("flight.csv"),row,StandardOpenOption.CREATE,StandardOpenOption.APPEND);
     Files.writeString(root.resolve("writer-report.txt"),output(controller,"Report"));
     if(ticks%20==0)event("STATUS "+output(controller,"Status"));
    }
    if(release>=0&&ticks<endTick&&!aborted&&(sp.getAltitude()<80||Math.abs(sp.getX()-32)>250||Math.abs(sp.getZ()-32)>250||Double.parseDouble(output(controller,"Active"))!=1)){aborted=true;var staff=PhysicsStaffServerHandler.get(ship.getLevel());if(!staff.isLocked(ship))staff.toggleLock(ship.getUniqueId());power(false);event("ABORT: test envelope exceeded; fixture locked; not a flight pass");Files.writeString(root.resolve("final-graph.snbt"),sp.graph.save().toString());server.halt(false);}
   }
   if(ticks==endTick){if(ship!=null&&!PhysicsStaffServerHandler.get(ship.getLevel()).isLocked(ship))PhysicsStaffServerHandler.get(ship.getLevel()).toggleLock(ship.getUniqueId());if(sp!=null){power(false);Files.writeString(root.resolve("final-graph.snbt"),sp.graph.save().toString());}fields(node("-operations")).get(3).setValue("MCREC1;"+(++ackRevision)+";FULL");event("COMPLETE: shock scenario ended, criteria scored separately");}
   if(ticks>=endTick+10 && ticks<endTick+45 && sp!=null){
   WNode operations=node("-operations");String page=fields(operations).get(1).getValue();String[] head=page.lines().findFirst().orElse("").split(";");
   if(head.length==9 && head[0].equals("MCLOG1")){exportTotal=Integer.parseInt(head[4]);int current=Integer.parseInt(head[3]);if(current==exportPage){Files.writeString(root.resolve("page-"+exportPage+".txt"),page);exportPage++;}}
   var sliders=operations.getElements().stream().filter(e->e instanceof WSlider).map(e->(WSlider)e).toList();if(exportPage<=exportTotal)sliders.get(1).setValue(exportPage);
  }
  if(ticks==endTick+45){if(exportTotal<1||exportPage!=exportTotal+1)throw new IllegalStateException("Incomplete server log export");event("EXPORT: "+exportTotal+" pages complete");server.halt(false);}
  }catch(Throwable error){try{Files.writeString(root.resolve("error.txt"),error.toString());event("ERROR "+error);}catch(Exception ignored){}error.printStackTrace();server.halt(false);}
 }
}
