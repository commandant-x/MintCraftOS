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
public class SpotQuadrupedGaitTunedProbe {
 static final java.util.concurrent.ConcurrentHashMap<BlockPos,java.util.concurrent.atomic.LongAdder> CONTACTS=new java.util.concurrent.ConcurrentHashMap<>();
 static final net.neoforged.neoforge.registries.DeferredRegister.Blocks BLOCKS=net.neoforged.neoforge.registries.DeferredRegister.createBlocks("mintcraft_probe");
 static final net.neoforged.neoforge.registries.DeferredBlock<Block> SENSOR=BLOCKS.register("quadruped_contact_floor",()->new ContactBlock());
 static class ContactBlock extends Block implements dev.ryanhcode.sable.api.block.BlockWithSubLevelCollisionCallback {
  ContactBlock(){super(net.minecraft.world.level.block.state.BlockBehaviour.Properties.of().strength(50f));}
  public dev.ryanhcode.sable.api.physics.callback.BlockSubLevelCollisionCallback sable$getCallback(){return (floor,body,v,f)->{CONTACTS.computeIfAbsent(body.immutable(),k->new java.util.concurrent.atomic.LongAdder()).increment();return dev.ryanhcode.sable.api.physics.callback.BlockSubLevelCollisionCallback.CollisionResult.NONE;};}
 }

 final boolean assemblyOnly=Boolean.getBoolean("mintcraft.spot.assemblyOnly");
 final Path out=Path.of("mintcraft-quadruped-gait-tuned"); final BlockPos base=new BlockPos(32,180,32);
 final Set<BlockPos> chassisBlocks=new HashSet<>(); final List<Leg> legs=new ArrayList<>();
 ServerSubLevel chassis; CreativeMotorBlockEntity motor; BlockPos reverseControl; int tick;double initialY;org.joml.Quaterniond initialQ;
 static class Leg { final String name;final int x,z; UUID kneeId,hipId,rollId;SwivelBearingBlockEntity roll,hip,knee;BlockPos rollControl,hipControl,kneeControl,footLocal;Leg(String n,int x,int z){name=n;this.x=x;this.z=z;} }
 public SpotQuadrupedGaitTunedProbe(net.neoforged.bus.api.IEventBus modBus){BLOCKS.register(modBus);NeoForge.EVENT_BUS.addListener(this::tick);legs.add(new Leg("front_left",0,0));legs.add(new Leg("front_right",20,0));legs.add(new Leg("rear_left",0,16));legs.add(new Leg("rear_right",20,16));}
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
 void audit(ServerLevel l)throws Exception{
  var c=SubLevelContainer.getContainer(l);StringBuilder s=new StringBuilder();int count=0,parts=0;
  for(Leg a:legs){int[] wood=new int[2];int i=0;for(UUID id:List.of(a.kneeId,a.hipId)){var sub=c.getSubLevel(id);if(sub==null)throw new IllegalStateException("missing segment "+id);var box=sub.getPlot().getBoundingBox();for(var at:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ()))if(l.getBlockState(at).is(net.minecraft.world.level.block.Blocks.OAK_PLANKS)){wood[i]++;if(i==0&&(a.footLocal==null||at.getY()<a.footLocal.getY()))a.footLocal=at.immutable();}i++;}
   for(UUID id:List.of(a.kneeId,a.hipId,a.rollId))if(c.getSubLevel(id)!=null)parts++;
   for(SwivelBearingBlockEntity sw:List.of(a.roll,a.hip,a.knee)){count++;if(!sw.isAssembled())throw new IllegalStateException("unassembled pivot");}
   s.append(a.name).append(" lower_planks=").append(wood[0]).append(" upper_planks=").append(wood[1]).append(" axes=z,x,x\n");
   if(wood[0]!=7||wood[1]!=7)throw new IllegalStateException(a.name+" wrong segment wood counts "+Arrays.toString(wood));
  }
  s.append("pivots=").append(count).append(" leg_bodies=").append(parts).append(" chassis=1 motor_count_observed=1 motor_rpm=").append(motor.getSpeed()).append('\n');
  Files.writeString(out.resolve("audit.txt"),s);if(count!=12||parts!=12)throw new IllegalStateException("incomplete quadruped");event("AUDIT pivots="+count+" leg_bodies="+parts+" chassis=1 motor=1");
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
  int n=tick>=340&&tick<1300?(tick-340)/120:-1;int[] order={2,1,0,3};var a=legs.get(n<0?2:order[n%4]);line.append(',').append(n<0?"none":a.name).append(',').append(a.knee.getExtraKinetics().getSpeed()).append(',').append(a.knee.getTargetAngleDegrees()).append(',').append(a.hip.getExtraKinetics().getSpeed()).append(',').append(a.hip.getTargetAngleDegrees());
  double total=0;var center=new org.joml.Vector3d();
  for(var part:c.getAllSubLevels()){double mass=part.getMassTracker().getMass();var local=part.getMassTracker().getCenterOfMass();var world=part.logicalPose().transformPosition(new org.joml.Vector3d(local),new org.joml.Vector3d());center.fma(mass,world);total+=mass;}
  if(total<=0)throw new IllegalStateException("invalid total mass");center.div(total);line.append(',').append(center.x()).append(',').append(center.y()).append(',').append(center.z()).append(',').append(total);
  Files.writeString(out.resolve("stand.csv"),line.append('\n'),StandardOpenOption.APPEND);}
 void releaseTickets(ServerLevel l)throws Exception{var c=SubLevelContainer.getContainer(l);int n=0;for(var sub:new ArrayList<>(c.getAllSubLevels()))if(c.removeForceLoadTicket(sub,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE))n++;event("Removed "+n+" forced tickets before saving");}
 void measureStand(ServerLevel l,String phase)throws Exception{
  var c=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);var pose=chassis.logicalPose();var v=pose.position();var q=pose.orientation();
  StringBuilder line=new StringBuilder().append(tick).append(',').append(phase).append(',').append(v.x()).append(',').append(v.y()).append(',').append(v.z()).append(',').append(q.x()).append(',').append(q.y()).append(',').append(q.z()).append(',').append(q.w()).append(',').append(staff.isLocked(chassis)).append(',').append(motor.getSpeed());
  for(Leg a:legs){var sub=c.getSubLevel(a.kneeId);var foot=a.footLocal;var point=new org.joml.Vector3d(foot.getX()+.5,foot.getY(),foot.getZ()+.5);var world=sub.logicalPose().transformPosition(point,new org.joml.Vector3d());
   var counter=CONTACTS.get(foot);line.append(',').append(world.x()).append(',').append(world.y()).append(',').append(world.z()).append(',').append(counter==null?0:counter.sum());
   for(UUID id:List.of(a.rollId,a.hipId,a.kneeId))line.append(',').append(staff.isLocked(c.getSubLevel(id)));
  }
  int n=tick>=340&&tick<1300?(tick-340)/120:-1;int[] order={2,1,0,3};var a=legs.get(n<0?2:order[n%4]);line.append(',').append(n<0?"none":a.name).append(',').append(a.knee.getExtraKinetics().getSpeed()).append(',').append(a.knee.getTargetAngleDegrees()).append(',').append(a.hip.getExtraKinetics().getSpeed()).append(',').append(a.hip.getTargetAngleDegrees());
  double total=0;var center=new org.joml.Vector3d();
  for(var part:c.getAllSubLevels()){double mass=part.getMassTracker().getMass();var local=part.getMassTracker().getCenterOfMass();var world=part.logicalPose().transformPosition(new org.joml.Vector3d(local),new org.joml.Vector3d());center.fma(mass,world);total+=mass;}
  if(total<=0)throw new IllegalStateException("invalid total mass");center.div(total);line.append(',').append(center.x()).append(',').append(center.y()).append(',').append(center.z()).append(',').append(total);
  Files.writeString(out.resolve("stand.csv"),line.append('\n'),StandardOpenOption.APPEND);
 }
 void tick(ServerTickEvent.Post e){var server=e.getServer();var l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);
   if(tick==80)for(Leg a:legs)a.kneeId=assemble(l,q(a,1,-8,1),a.name+"_knee");
   if(tick==120)for(Leg a:legs)a.hipId=assemble(l,q(a,0,-1,1),a.name+"_hip");
   if(tick==160)for(Leg a:legs)a.rollId=assemble(l,q(a,0,0,0),a.name+"_roll");
   if(tick==200)assembleChassis(l);
   if(tick==220){audit(l);Files.writeString(out.resolve("mass.txt"),"chassis_mass="+chassis.getMassTracker().getMass()+"\n");}
   if(tick==230){var c=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);for(Leg a:legs)for(UUID id:List.of(a.kneeId,a.hipId,a.rollId)){var sub=c.getSubLevel(id);if(staff.isLocked(sub))staff.removeLock(sub);}motor.generatedSpeed.setValue(4);event("Released twelve leg bodies; chassis temporarily locked; motor set to 4 RPM");}
   if(tick==240){for(int x=-12;x<=26;x++)for(int z=-7;z<=24;z++)l.setBlock(p(x,-15,z),SENSOR.get().defaultBlockState(),3);event("Placed full-block instrumented contact surface");}
   if(tick==280){StringBuilder h=new StringBuilder("tick,phase,x,y,z,qx,qy,qz,qw,chassis_locked,motor_rpm");for(Leg a:legs)h.append(',').append(a.name).append("_foot_x,").append(a.name).append("_foot_y,").append(a.name).append("_foot_z,").append(a.name).append("_contacts,").append(a.name).append("_roll_locked,").append(a.name).append("_hip_locked,").append(a.name).append("_knee_locked");h.append(",active_leg,test_knee_rpm,test_knee_target,test_hip_rpm,test_hip_target,com_x,com_y,com_z,total_mass");Files.writeString(out.resolve("stand.csv"),h.append('\n'));measureStand(l,"before_release");PhysicsStaffServerHandler.get(l).removeLock(chassis);event("Released chassis without guide; motor runs with all clutches disengaged");}
   if(tick==330){initialY=chassis.logicalPose().position().y();initialQ=new org.joml.Quaterniond(chassis.logicalPose().orientation()).normalize();event("Stored pre-gait chassis pose for abort monitoring");}
   if(tick>=340&&tick<1300){int n=(tick-340)/120,phase=(tick-340)%120;int[] order={2,1,0,3};Leg a=legs.get(order[n%4]);boolean reversed=a==legs.get(0)||a==legs.get(3);
    if(phase==0){setPower(l,reverseControl,reversed);event("Gait cycle="+n+" leg="+a.name+" initial_reverse="+reversed);}
    if(phase==10)setPower(l,a.kneeControl,false);
    if(phase==20)setPower(l,a.kneeControl,true);
    if(phase==30)setPower(l,a.hipControl,false);
    if(phase==36)setPower(l,a.hipControl,true);
    if(phase==46)setPower(l,reverseControl,!reversed);
    if(phase==56)setPower(l,a.kneeControl,false);
    if(phase==66)setPower(l,a.kneeControl,true);
    if(phase==76)setPower(l,a.hipControl,false);
    if(phase==82)setPower(l,a.hipControl,true);
    if(phase==92)setPower(l,reverseControl,false);
   }
   if(tick==1320){motor.generatedSpeed.setValue(0);event("Gait motor stopped after eight reduced-amplitude cycles");}
   if(tick>=290&&tick<=1400&&tick%10==0){measureStand(l,"after_release");
    if(tick>=340){var current=new org.joml.Quaterniond(chassis.logicalPose().orientation()).normalize();double dot=Math.min(1,Math.abs(initialQ.dot(current)));double angle=Math.toDegrees(2*Math.acos(dot));double drop=initialY-chassis.logicalPose().position().y();
     if(angle>25||drop>2){for(Leg leg:legs)for(BlockPos at:List.of(leg.rollControl,leg.hipControl,leg.kneeControl))setPower(l,at,true);motor.generatedSpeed.setValue(0);event("ABORT stability threshold: tilt="+angle+" drop="+drop);Files.writeString(out.resolve("aborted.txt"),"tick="+tick+" tilt="+angle+" drop="+drop+"\n");Files.writeString(out.resolve("complete.txt"),"Gait aborted on stability threshold; inspect trace.\n");server.halt(false);}
    }
   }
   if(tick==1400){Files.writeString(out.resolve("complete.txt"),"Eight reduced-amplitude cycles attempted; inspect support and trajectory.\n");server.halt(false);}

  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
