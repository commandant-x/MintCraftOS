package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import com.simibubi.create.content.contraptions.glue.SuperGlueEntity;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import java.nio.file.*;
import java.util.*;

/** Four-leg isolated server prototype; one motor, twelve swivels. No walking claim. */
@Mod("mintcraft_probe")
public class SpotQuadrupedSlimeFeetProbe {
 final boolean staticTest=Boolean.getBoolean("mintcraft.spot.staticTest"); final int speed=Integer.getInteger("mintcraft.spot.motorSpeed",8); final int scale=Integer.getInteger("mintcraft.spot.gaitScale",speed/4); final int interval=(int)Math.ceil(970.0/scale);
 final boolean assemblyOnly=Boolean.getBoolean("mintcraft.spot.assemblyOnly");
 final Path out=Path.of("mintcraft-quadruped-slime-feet"); final BlockPos base=new BlockPos(32,180,32);
 final Set<BlockPos> chassisBlocks=new HashSet<>(); final List<Leg> legs=new ArrayList<>();
 ServerSubLevel chassis; CreativeMotorBlockEntity motor; BlockPos reverseControl; int tick;
 dev.devce.rocketnautics.content.blocks.SputnikBlockEntity sputnik;dev.devce.websnodelib.api.WNode operator,controller;double initialY;org.joml.Quaterniond initialQ;
 static class Leg { final String name;final int x,z; UUID kneeId,hipId,rollId;SwivelBearingBlockEntity roll,hip,knee;BlockPos rollControl,hipControl,kneeControl,footLocal;Leg(String n,int x,int z){name=n;this.x=x;this.z=z;} }
 public SpotQuadrupedSlimeFeetProbe(){NeoForge.EVENT_BUS.addListener(this::tick);legs.add(new Leg("front_left",0,0));legs.add(new Leg("front_right",20,0));legs.add(new Leg("rear_left",0,16));legs.add(new Leg("rear_right",20,16));}
 BlockPos p(int x,int y,int z){return base.offset(x,y,z);} BlockPos q(Leg a,int x,int y,int z){return p(a.x+x,y,a.z+z);}
 BlockState b(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 BlockState axis(String id,Direction.Axis axis){return b(id).setValue(BlockStateProperties.AXIS,axis);}
 void put(ServerLevel l,BlockPos p,BlockState s){if(!l.getBlockState(p).isAir())throw new IllegalStateException("Overlapping block at "+p+": "+l.getBlockState(p)+" -> "+s);l.setBlock(p,s,3);}
 void part(ServerLevel l,Leg a,int x,int y,int z,BlockState s){put(l,q(a,x,y,z),s);}
 void body(ServerLevel l,int x,int y,int z,BlockState s){BlockPos at=p(x,y,z);put(l,at,s);chassisBlocks.add(at);}
 void glue(ServerLevel l,BlockPos a,BlockPos b){l.addFreshEntity(new SuperGlueEntity(l,SuperGlueEntity.span(a,b)));}
 void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 void setup(ServerLevel l)throws Exception{
  Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");
  for(int cx=1;cx<=3;cx++)for(int cz=1;cz<=3;cz++)l.setChunkForced(cx,cz,true);
  var plank=b("minecraft:oak_planks");var red=b("minecraft:redstone_block");var bearing=b("simulated:swivel_bearing");
  body(l,-12,0,-4,b("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.EAST));
  ((CreativeMotorBlockEntity)l.getBlockEntity(p(-12,0,-4))).generatedSpeed.setValue(0);
  body(l,-11,0,-4,axis("create:gearshift",Direction.Axis.X));
  for(int x=-10;x<=10;x++)body(l,x,0,-4,axis(x==-10||x==10?"create:gearbox":"create:shaft",x==-10||x==10?Direction.Axis.Y:Direction.Axis.X));
  for(int x:new int[]{-10,10})for(int z=-3;z<=15;z++)body(l,x,0,z,axis(z==-1||z==15?"create:gearbox":"create:shaft",z==-1||z==15?Direction.Axis.Y:Direction.Axis.Z));
  for(Leg a:legs){
   int trunk=a.x-10;
   for(int x=trunk+1;x<a.x;x++)body(l,x,0,a.z-1,axis("create:shaft",Direction.Axis.X));
   body(l,a.x,0,a.z-1,axis("create:gearbox",Direction.Axis.Y));
   body(l,a.x+1,0,a.z-1,axis("create:clutch",Direction.Axis.X));
   body(l,a.x+2,0,a.z-1,axis("create:gearbox",Direction.Axis.Y));
   body(l,a.x+2,0,a.z,axis("create:cogwheel",Direction.Axis.Z));
   body(l,a.x+1,1,a.z-1,red);
   body(l,a.x+1,0,a.z,axis("create:cogwheel",Direction.Axis.Z));
   body(l,a.x,0,a.z,bearing.setValue(BlockStateProperties.FACING,Direction.SOUTH));
   part(l,a,0,0,1,axis("create:shaft",Direction.Axis.Z));
   part(l,a,0,0,2,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,-1,0,2,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,-1,0,1,axis("create:gearbox",Direction.Axis.X));
   part(l,a,-1,-1,1,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,-2,0,2,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,-2,-1,2,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,-1,-1,2,axis("create:clutch",Direction.Axis.X));
   part(l,a,-1,-1,3,red);
   part(l,a,0,-1,2,axis("create:cogwheel",Direction.Axis.X));
   part(l,a,0,-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
   for(int y=-1;y>=-7;y--)if(y!=-1)part(l,a,1,y,1,plank);
   part(l,a,1,-1,1,axis("create:shaft",Direction.Axis.X));part(l,a,1,-1,0,plank);
   part(l,a,2,-1,1,axis("create:gearbox",Direction.Axis.Z));
   for(int y=-2;y>=-6;y--)part(l,a,2,y,1,axis("create:shaft",Direction.Axis.Y));
   part(l,a,2,-7,1,axis("create:gearbox",Direction.Axis.X));
   part(l,a,2,-7,2,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,3,-7,2,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,3,-8,2,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,2,-8,2,axis("create:clutch",Direction.Axis.X));
   part(l,a,2,-8,3,red);part(l,a,1,-8,2,axis("create:cogwheel",Direction.Axis.X));
   part(l,a,1,-8,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
   for(int y=-8;y>=-14;y--)part(l,a,2,y,1,plank);
   for(int x=-3;x>=-7;x--)part(l,a,x,0,2,b(x<=-5?"minecraft:iron_block":"minecraft:oak_planks"));
   glue(l,q(a,-2,0,2),q(a,-7,0,2));glue(l,q(a,-1,-1,1),q(a,0,0,2));
   glue(l,q(a,-2,-1,2),q(a,-1,0,2));glue(l,q(a,-1,-1,2),q(a,-1,-1,3));
   glue(l,q(a,1,-8,1),q(a,1,-1,1));glue(l,q(a,1,-1,0),q(a,1,-1,1));
   glue(l,q(a,1,-7,1),q(a,2,-1,1));glue(l,q(a,2,-7,1),q(a,2,-7,2));
   glue(l,q(a,2,-7,2),q(a,3,-7,2));glue(l,q(a,3,-7,2),q(a,3,-8,2));
   glue(l,q(a,3,-8,2),q(a,1,-8,2));glue(l,q(a,2,-8,2),q(a,2,-8,3));
   glue(l,q(a,2,-14,1),q(a,2,-8,1));
  }
  for(int x=0;x<=20;x++)for(int z=0;z<=16;z++)body(l,x,2,z,plank);
  event("Built four legs, two 7-block segments each, twelve swivels and one creative motor; all clutches initially powered");
 }
 UUID assemble(ServerLevel l,BlockPos pos,String label)throws Exception{
  if(!(l.getBlockEntity(pos) instanceof SwivelBearingBlockEntity b))throw new IllegalStateException(label+" missing at "+pos);
  b.assemble();UUID id=b.getSubLevelID();if(!b.isAssembled()||id==null)throw new IllegalStateException(label+" assembly failed: "+b.getLastAssemblyException());
  var sub=(ServerSubLevel)SubLevelContainer.getContainer(l).getSubLevel(id);if(sub==null)throw new IllegalStateException(label+" child missing");
  SubLevelContainer.getContainer(l).addForceLoadTicket(sub,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE);
  var staff=PhysicsStaffServerHandler.get(l);if(!staff.isLocked(sub))staff.toggleLock(id);event("Assembled "+label+" child="+id);return id;
 }
 void assembleChassis(ServerLevel l)throws Exception{
  chassis=dev.ryanhcode.sable.api.SubLevelAssemblyHelper.assembleBlocks(l,p(0,0,0),chassisBlocks,dev.ryanhcode.sable.companion.math.BoundingBox3i.from(chassisBlocks));
  if(chassis==null)throw new IllegalStateException("chassis assembly failed");
  var c=SubLevelContainer.getContainer(l);c.addForceLoadTicket(chassis,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE);PhysicsStaffServerHandler.get(l).toggleLock(chassis.getUniqueId());
  var shift=b("create:gearshift").getBlock();
  for(var h:chassis.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
   if(be instanceof CreativeMotorBlockEntity m){if(motor!=null)throw new IllegalStateException("more than one motor");motor=m;}
   if(be.getBlockState().is(shift))reverseControl=be.getBlockPos().above();
   if(be instanceof SwivelBearingBlockEntity sw)for(Leg a:legs)if(a.rollId.equals(sw.getSubLevelID()))a.roll=sw;
  }
  if(motor==null||reverseControl==null)throw new IllegalStateException("motor or reversing control missing");
  for(Leg a:legs){
   if(a.roll==null)throw new IllegalStateException(a.name+" root bearing missing from chassis");
   a.rollControl=a.roll.getBlockPos().offset(1,1,-1);
   a.hip=findBearing(l,a.rollId,a.hipId);a.knee=findBearing(l,a.hipId,a.kneeId);
   a.hipControl=findClutch(l,a.rollId);a.kneeControl=findClutch(l,a.hipId);
   for(BlockPos at:List.of(a.rollControl,a.hipControl,a.kneeControl))if(!l.getBlockState(at).is(net.minecraft.world.level.block.Blocks.REDSTONE_BLOCK))throw new IllegalStateException(a.name+" missing redstone at "+at);
  }
  event("Chassis assembled and locked; one motor, four root pivots and eight nested pivots found");
 }
 SwivelBearingBlockEntity findBearing(ServerLevel l,UUID parent,UUID id){var part=SubLevelContainer.getContainer(l).getSubLevel(parent);for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity sw&&id.equals(sw.getSubLevelID()))return sw;throw new IllegalStateException("nested bearing "+id+" missing");}
 BlockPos findClutch(ServerLevel l,UUID parent){var part=SubLevelContainer.getContainer(l).getSubLevel(parent);BlockPos found=null;Block clutch=b("create:clutch").getBlock();for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be.getBlockState().is(clutch)){if(found!=null)throw new IllegalStateException("multiple clutches in "+parent);found=be.getBlockPos().south();}if(found==null)throw new IllegalStateException("clutch missing in "+parent);return found;}
 void installFeet(ServerLevel l)throws Exception{
  boolean useSlime=Boolean.getBoolean("mintcraft.spot.slimeFeet");var c=SubLevelContainer.getContainer(l);
  for(Leg leg:legs){var sub=c.getSubLevel(leg.kneeId);if(sub==null)throw new IllegalStateException("missing lower leg");var box=sub.getPlot().getBoundingBox();BlockPos lowest=null;int planks=0,slimes=0;
   for(var p:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ())){var state=l.getBlockState(p);if(state.is(net.minecraft.world.level.block.Blocks.OAK_PLANKS)){planks++;if(lowest==null||p.getY()<lowest.getY())lowest=p.immutable();}if(state.is(net.minecraft.world.level.block.Blocks.SLIME_BLOCK)){slimes++;leg.footLocal=p.immutable();}}
   if(useSlime&&slimes==0){if(planks!=7||lowest==null)throw new IllegalStateException("unexpected unmodified lower segment for "+leg.name);if(!l.setBlock(lowest,net.minecraft.world.level.block.Blocks.SLIME_BLOCK.defaultBlockState(),3))throw new IllegalStateException("could not replace foot block");leg.footLocal=lowest;slimes++;planks--;event("Replaced lowest plank with slime foot for "+leg.name+" local="+lowest);}
   if(useSlime&&(slimes!=1||planks!=6))throw new IllegalStateException("wrong slime foot composition for "+leg.name+" planks="+planks+" slime="+slimes);
   if(!useSlime&&(slimes!=0||planks!=7))throw new IllegalStateException("control leg unexpectedly modified");
   if(!useSlime)leg.footLocal=lowest;
  }
 }
 void audit(ServerLevel l)throws Exception{
  var c=SubLevelContainer.getContainer(l);StringBuilder s=new StringBuilder();int count=0,parts=0;boolean slime=Boolean.getBoolean("mintcraft.spot.slimeFeet");
  for(Leg a:legs){int[] wood=new int[2];int lowerSlime=0,i=0;for(UUID id:List.of(a.kneeId,a.hipId)){var sub=c.getSubLevel(id);if(sub==null)throw new IllegalStateException("missing segment "+id);var box=sub.getPlot().getBoundingBox();for(var at:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ())){var state=l.getBlockState(at);if(state.is(net.minecraft.world.level.block.Blocks.OAK_PLANKS))wood[i]++;if(i==0&&state.is(net.minecraft.world.level.block.Blocks.SLIME_BLOCK))lowerSlime++;}i++;}
   for(UUID id:List.of(a.kneeId,a.hipId,a.rollId))if(c.getSubLevel(id)!=null)parts++;
   for(SwivelBearingBlockEntity sw:List.of(a.roll,a.hip,a.knee)){count++;if(!sw.isAssembled())throw new IllegalStateException("unassembled pivot");}
   if(a.footLocal==null||wood[1]!=7||wood[0]!=(slime?6:7)||lowerSlime!=(slime?1:0))throw new IllegalStateException(a.name+" invalid leg composition");
   s.append(a.name).append(" lower_planks=").append(wood[0]).append(" lower_slime=").append(lowerSlime).append(" lower_total=").append(wood[0]+lowerSlime).append(" upper_planks=").append(wood[1]).append(" foot=").append(a.footLocal).append(" axes=z,x,x\n");
  }
  s.append("pivots=").append(count).append(" leg_bodies=").append(parts).append(" chassis=1 motor_count_observed=1 motor_rpm=").append(motor.getSpeed()).append('\n');Files.writeString(out.resolve("audit.txt"),s);if(count!=12||parts!=12)throw new IllegalStateException("incomplete quadruped");event("AUDIT pivots="+count+" leg_bodies="+parts+" chassis=1 motor=1 slimeFeet="+slime);
 }
 void setPower(ServerLevel l,BlockPos at,boolean on)throws Exception{l.setBlock(at,on?b("minecraft:redstone_block"):net.minecraft.world.level.block.Blocks.AIR.defaultBlockState(),3);}
 BlockPos control(Leg a,int axis){return axis==0?a.rollControl:axis==1?a.hipControl:a.kneeControl;}
 SwivelBearingBlockEntity joint(Leg a,int axis){return axis==0?a.roll:axis==1?a.hip:a.knee;}
 void sample(ServerLevel l,int caseId,String phase)throws Exception{
  StringBuilder s=new StringBuilder().append(tick).append(',').append(caseId).append(',').append(phase).append(',').append(motor.getSpeed());
  for(Leg a:legs)for(int j=0;j<3;j++){var joint=joint(a,j);s.append(',').append(joint.getExtraKinetics().getSpeed()).append(',').append(joint.getTargetAngleDegrees());}
  var c=SubLevelContainer.getContainer(l);var cq=chassis.logicalPose().orientation();s.append(',').append(cq.x()).append(',').append(cq.y()).append(',').append(cq.z()).append(',').append(cq.w());
  for(Leg a:legs)for(UUID id:List.of(a.rollId,a.hipId,a.kneeId)){var sub=c.getSubLevel(id);if(sub==null)throw new IllegalStateException("missing measured body "+id);var q=sub.logicalPose().orientation();s.append(',').append(q.x()).append(',').append(q.y()).append(',').append(q.z()).append(',').append(q.w());}
  Files.writeString(out.resolve("drive.csv"),s.append('\n'),StandardOpenOption.APPEND);
 }
 void recordStand(ServerLevel l,String phase)throws Exception{var pose=chassis.logicalPose();var v=pose.position();var q=pose.orientation();StringBuilder line=new StringBuilder().append(tick).append(',').append(phase).append(',').append(v.x()).append(',').append(v.y()).append(',').append(v.z()).append(',').append(q.x()).append(',').append(q.y()).append(',').append(q.z()).append(',').append(q.w()).append(',').append(PhysicsStaffServerHandler.get(l).isLocked(chassis));
  var c=SubLevelContainer.getContainer(l);for(Leg a:legs){if(a.footLocal==null)throw new IllegalStateException("missing foot");var point=new org.joml.Vector3d(a.footLocal.getX()+.5,a.footLocal.getY(),a.footLocal.getZ()+.5);var world=c.getSubLevel(a.kneeId).logicalPose().transformPosition(point,new org.joml.Vector3d());line.append(',').append(world.x()).append(',').append(world.y()).append(',').append(world.z());}
  Files.writeString(out.resolve("stand.csv"),line.append('\n'),StandardOpenOption.APPEND);}
 void releaseTickets(ServerLevel l)throws Exception{var c=SubLevelContainer.getContainer(l);int n=0;for(var sub:new ArrayList<>(c.getAllSubLevels()))if(c.removeForceLoadTicket(sub,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE))n++;event("Removed "+n+" forced tickets before saving");}
 SwivelBearingBlockEntity onlyChild(ServerLevel l,UUID id){
  var part=SubLevelContainer.getContainer(l).getSubLevel(id);if(part==null)throw new IllegalStateException("missing part "+id);SwivelBearingBlockEntity result=null;
  for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity b){if(result!=null)throw new IllegalStateException("multiple bearings in child");result=b;}
  if(result==null||!result.isAssembled()||result.getSubLevelID()==null)throw new IllegalStateException("missing assembled child");return result;
 }
 void recover(ServerLevel l)throws Exception{
  Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");var c=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);
  int motors=0;for(var part:c.getAllSubLevels())for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof CreativeMotorBlockEntity m){motors++;motor=m;chassis=part;}
  if(motors!=1||chassis==null||motor.getSpeed()!=0)throw new IllegalStateException("missing, duplicate or moving motor");
  for(var part:c.getAllSubLevels())if(staff.isLocked(part))throw new IllegalStateException("body staff-locked after reload: "+part.getUniqueId());
  List<SwivelBearingBlockEntity> roots=new ArrayList<>();var shift=b("create:gearshift").getBlock();
  for(var h:chassis.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
   if(be instanceof SwivelBearingBlockEntity sw)roots.add(sw);if(be.getBlockState().is(shift))reverseControl=be.getBlockPos().above();if(be instanceof dev.devce.rocketnautics.content.blocks.SputnikBlockEntity sp)sputnik=sp;
  }
  roots.sort(Comparator.comparingInt((SwivelBearingBlockEntity sw)->sw.getBlockPos().getZ()).thenComparingInt(sw->sw.getBlockPos().getX()));
  if(roots.size()!=4||reverseControl==null||sputnik==null)throw new IllegalStateException("missing root pivots, reverser or Sputnik");
  for(var node:sputnik.graph.getNodes())if(node.getCustomData().getString("code").contains("MintSpotOperator"))operator=node;
  if(operator==null||sputnik.graph.getNodes().size()!=2||sputnik.graph.getConnections().size()!=2)throw new IllegalStateException("saved Sputnik operator graph missing");
  for(int i=0;i<4;i++){Leg a=legs.get(i);a.roll=roots.get(i);a.rollId=a.roll.getSubLevelID();a.hip=onlyChild(l,a.rollId);a.hipId=a.hip.getSubLevelID();a.knee=onlyChild(l,a.hipId);a.kneeId=a.knee.getSubLevelID();a.rollControl=a.roll.getBlockPos().offset(1,1,-1);a.hipControl=findClutch(l,a.rollId);a.kneeControl=findClutch(l,a.hipId);}
  event("Recovered one motor and all four three-axis legs with all bodies unlocked");
 }
 void input(String name,double value){var boxes=operator.getElements().stream().filter(e->e instanceof dev.devce.websnodelib.api.elements.WCheckbox).map(e->(dev.devce.websnodelib.api.elements.WCheckbox)e).toList();if(boxes.size()!=2)throw new IllegalStateException("operator checkboxes missing");boxes.get(name.equals("Enable")?0:1).setChecked(value>0);}
 int received(ServerLevel l,BlockPos p){var be=l.getBlockEntity(p);if(!(be instanceof com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity link))throw new IllegalStateException("receiver missing: "+p);return link.getReceivedSignal();}
 void verifyClosed(ServerLevel l)throws Exception{for(Leg a:legs)for(BlockPos at:List.of(a.rollControl,a.hipControl,a.kneeControl))if(received(l,at)!=15)throw new IllegalStateException("clutch receiver not powered: "+at);if(received(l,reverseControl)!=0)throw new IllegalStateException("reverser not zero");event("All 12 receivers closed and reverser zero");}
 void sampleWireless(ServerLevel l)throws Exception{StringBuilder line=new StringBuilder().append(tick).append(',').append(motor.getSpeed()).append(',').append(received(l,reverseControl));for(Leg a:legs)for(int j=0;j<3;j++)line.append(',').append(received(l,control(a,j))).append(',').append(joint(a,j).getExtraKinetics().getSpeed());Files.writeString(out.resolve("wireless.csv"),line.append('\n'),StandardOpenOption.APPEND);}
 void buildCourse(ServerLevel l)throws Exception{
  // x=16..72 accommodates the 21-block-wide machine and its feet.
  // The chassis start is approximately z=42.27; the finish is at z=292.27.
  for(int x=16;x<=72;x++)for(int z=20;z<=315;z++)l.setBlock(new BlockPos(x,165,z),b("minecraft:stone"),2);
  int[] strips={64,82,112,152,202,252,286};String[] blocks={"minecraft:white_carpet","minecraft:stone_slab","minecraft:stone_slab","minecraft:stone","minecraft:stone_slab","minecraft:stone","minecraft:stone_slab"};
  for(int i=0;i<strips.length;i++)for(int x=22;x<=66;x++)l.setBlock(new BlockPos(x,166,strips[i]),b(blocks[i]),2);
  for(int x=16;x<=72;x++){l.setBlock(new BlockPos(x,165,42),b("minecraft:lime_concrete"),2);l.setBlock(new BlockPos(x,165,292),b("minecraft:red_concrete"),2);}
  Files.writeString(out.resolve("course.txt"),"start chassis z=42.27; goal +250 blocks z=292.27; floor x=16..72 z=20..315 y=165\nobstacles across x=22..66 at y=166: carpet z=64; bottom slabs z=82,112,202,286; full blocks z=152,252\n");
  event("Built 250-block marked course with seven transverse obstacle strips");
 }
 void tick(ServerTickEvent.Post e){var server=e.getServer();var l=server.overworld();tick++;
  try{
   if(tick==20)for(int x=1;x<=4;x++)for(int z=1;z<=20;z++)l.setChunkForced(x,z,true);
   if(tick==200){recover(l);installFeet(l);String candidate=System.getProperty("mintcraft.spot.courseController");for(var node:sputnik.graph.getNodes())if(node.getCustomData().getString("code").contains("MintSpotQuadrupedGait"))controller=node;if(controller==null)throw new IllegalStateException("controller missing");if(candidate!=null){controller.getElements().clear();controller.getCustomData().putString("code",Files.readString(Path.of(candidate)));event("Installed feedback controller from "+candidate);}String uiSource=System.getProperty("mintcraft.spot.operator");if(uiSource!=null){operator.getElements().clear();operator.getCustomData().putString("code",Files.readString(Path.of(uiSource)));event("Installed 8 RPM operator interface");}Files.writeString(out.resolve("loaded-controller.lua"),controller.getCustomData().getString("code"));Files.writeString(out.resolve("loaded-operator.lua"),operator.getCustomData().getString("code"));audit(l);StringBuilder h=new StringBuilder("tick,phase,x,y,z,qx,qy,qz,qw,chassis_locked");for(Leg a:legs)h.append(',').append(a.name).append("_foot_x,").append(a.name).append("_foot_y,").append(a.name).append("_foot_z");Files.writeString(out.resolve("stand.csv"),h.append('\n'));StringBuilder w=new StringBuilder("tick,motor_rpm,reverse_signal");for(Leg a:legs)for(String j:List.of("roll","hip","knee"))w.append(',').append(a.name).append('_').append(j).append("_signal,").append(a.name).append('_').append(j).append("_rpm");Files.writeString(out.resolve("wireless.csv"),w.append('\n'));}
   if(tick==210){Files.writeString(out.resolve("telemetry.csv"),"tick,pitch,yaw,roll,x,y,z,yaw_error,tilt_guard,pose_valid\n");buildCourse(l);if(Boolean.getBoolean("mintcraft.spot.courseBuildOnly")){verifyClosed(l);for(int x=1;x<=4;x++)for(int z=1;z<=20;z++)l.setChunkForced(x,z,false);Files.writeString(out.resolve("complete.txt"),"Course constructed; motor remains stopped.\n");server.halt(false);return;}}
   if(tick==220)verifyClosed(l);
   if(tick==230){if(speed!=8&&speed!=16&&speed!=32&&speed!=64&&speed!=128&&speed!=256)throw new IllegalStateException("speed must be 8, 16, 32, 64, 128 or 256");motor.generatedSpeed.setValue(staticTest?0:speed);event("Motor set to "+(staticTest?0:speed)+" RPM after closed receiver check");}
   if(tick==250){input("Enable",staticTest?0:1);input("Start",0);event(staticTest?"Standing disturbance test; controls off":"Armed saved Sputnik interface");}
   if(tick==270){recordStand(l,"baseline");initialY=chassis.logicalPose().position().y();initialQ=new org.joml.Quaterniond(chassis.logicalPose().orientation()).normalize();initialZ=chassis.logicalPose().position().z();}
   if(tick==Integer.getInteger("mintcraft.spot.kickTick",2500)&&Double.parseDouble(System.getProperty("mintcraft.spot.kick","0"))!=0){double dv=Double.parseDouble(System.getProperty("mintcraft.spot.kick"));double mass=chassis.getMassTracker().getMass();dev.ryanhcode.sable.api.physics.handle.RigidBodyHandle.of(chassis).applyLinearAndAngularImpulse(new org.joml.Vector3d(mass*dv,0,0),new org.joml.Vector3d());event("Applied one lateral chassis impulse: nominal delta_v="+dv+" chassis_mass="+mass);}
   if(tick>=280){sampleWireless(l);if(tick%10==0){StringBuilder tel=new StringBuilder().append(tick);for(String n:List.of("Probe pitch","Probe yaw","Probe roll","Probe x","Probe y","Probe z","Yaw error","Tilt guard","Pose valid")){String v=controller.getOutputs().stream().filter(pin->pin.getName().equals(n)).findFirst().map(pin->pin.getValueAsString()).orElse("missing");tel.append(',').append(v);}Files.writeString(out.resolve("telemetry.csv"),tel.append('\n'),StandardOpenOption.APPEND);}int phase=(tick-280)%interval;if(!staticTest&&phase==0){input("Start",1);event("Start sequence="+((tick-280)/interval));}if(!staticTest&&phase==1)input("Start",0);
    if(true){recordStand(l,"running");var pose=chassis.logicalPose();var current=new org.joml.Quaterniond(pose.orientation()).normalize();double dot=Math.min(1,Math.abs(initialQ.dot(current)));double angle=Math.toDegrees(2*Math.acos(dot));double drop=initialY-pose.position().y();double progress=pose.position().z()-initialZ;String guardValue=controller.getOutputs().stream().filter(pin->pin.getName().equals("Tilt guard")).findFirst().map(pin->pin.getValueAsString()).orElse("0");boolean guard=Double.parseDouble(guardValue)>0.5;
     if(guard||angle>25||drop>2||progress>=250||tick>=280+Integer.getInteger("mintcraft.spot.duration",1800)){String result=guard?"CONTROLLER_GUARD":progress>=250?"GOAL":angle>25||drop>2?"ABORT_STABILITY":"TIME_LIMIT";input("Enable",0);motor.generatedSpeed.setValue(0);event(result+" progress="+progress+" tilt="+angle+" drop="+drop);Files.writeString(out.resolve("result.txt"),result+" tick="+tick+" progress="+progress+" tilt="+angle+" drop="+drop+"\n");Files.writeString(out.resolve("complete.txt"),"Course trial ended; inspect result and traces.\n");server.halt(false);}
    }
   }
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
 double initialZ;
}
