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
public class SpotQuadrupedSpeed25Probe {
 final boolean assemblyOnly=Boolean.getBoolean("mintcraft.spot.assemblyOnly");
 final Path out=Path.of("mintcraft-quadruped-wireless128"); final BlockPos base=new BlockPos(32,180,32);
 final Set<BlockPos> chassisBlocks=new HashSet<>(); final List<Leg> legs=new ArrayList<>();
 ServerSubLevel chassis; CreativeMotorBlockEntity motor; BlockPos reverseControl; int tick,glueWait;
 static class Leg { final String name;final int x,z; UUID kneeId,hipId,rollId;SwivelBearingBlockEntity roll,hip,knee;BlockPos rollControl,hipControl,kneeControl,rollReverse,hipReverse,kneeReverse,footLocal;Leg(String n,int x,int z){name=n;this.x=x;this.z=z;} }
 public SpotQuadrupedSpeed25Probe(){NeoForge.EVENT_BUS.addListener(this::tick);legs.add(new Leg("front_left",0,0));legs.add(new Leg("front_right",20,0));legs.add(new Leg("rear_left",0,16));legs.add(new Leg("rear_right",20,16));}
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
   body(l,a.x+2,0,a.z,axis("create:gearbox",Direction.Axis.X));
   body(l,a.x+2,1,a.z,axis("create:gearbox",Direction.Axis.X));
   body(l,a.x+2,1,a.z+1,axis("create:gearshift",Direction.Axis.Z));
   body(l,a.x+2,1,a.z+2,axis("create:cogwheel",Direction.Axis.Z));
   body(l,a.x+1,0,a.z+2,axis("create:large_cogwheel",Direction.Axis.Z));
   body(l,a.x+1,0,a.z+1,axis("create:shaft",Direction.Axis.Z));
   body(l,a.x+1,0,a.z,axis("create:cogwheel",Direction.Axis.Z));
   body(l,a.x+1,1,a.z-1,red);
   body(l,a.x,0,a.z,bearing.setValue(BlockStateProperties.FACING,Direction.SOUTH));
   part(l,a,0,0,1,axis("create:shaft",Direction.Axis.Z));
   part(l,a,0,0,2,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,-1,0,2,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,-1,0,1,axis("create:gearbox",Direction.Axis.X));
   part(l,a,-1,-1,1,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,-2,0,2,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,-2,-1,2,axis("create:clutch",Direction.Axis.Y));
   part(l,a,-2,-1,3,red);
   part(l,a,-2,-2,2,axis("create:gearshift",Direction.Axis.Y));
   part(l,a,-2,-3,2,axis("create:gearbox",Direction.Axis.Z));
   part(l,a,-1,-3,2,axis("create:cogwheel",Direction.Axis.X));
   part(l,a,-1,-2,1,axis("create:large_cogwheel",Direction.Axis.X));
   part(l,a,0,-2,1,axis("create:cogwheel",Direction.Axis.X));
   part(l,a,0,-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
   for(int y=-1;y>=-7;y--)if(y!=-1)part(l,a,1,y,1,plank);
   part(l,a,1,-1,1,axis("create:shaft",Direction.Axis.X));part(l,a,1,-1,0,plank);
   part(l,a,2,-1,1,axis("create:gearbox",Direction.Axis.Z));
   for(int y=-2;y>=-6;y--)part(l,a,2,y,1,axis("create:shaft",Direction.Axis.Y));
   part(l,a,2,-7,1,axis("create:gearbox",Direction.Axis.X));
   part(l,a,2,-7,0,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,1,-7,0,axis("create:clutch",Direction.Axis.X));
   part(l,a,1,-7,-1,red);
   part(l,a,0,-7,0,axis("create:gearshift",Direction.Axis.X));
   part(l,a,-1,-7,0,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,-1,-7,1,axis("create:gearbox",Direction.Axis.Y));
   part(l,a,-2,-7,1,axis("create:cogwheel",Direction.Axis.X));
   part(l,a,-2,-8,0,axis("create:large_cogwheel",Direction.Axis.X));
   part(l,a,-1,-8,0,axis("create:shaft",Direction.Axis.X));
   part(l,a,0,-8,0,axis("create:shaft",Direction.Axis.X));
   part(l,a,1,-8,0,axis("create:cogwheel",Direction.Axis.X));
   part(l,a,1,-8,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
   for(int y=-8;y>=-14;y--)part(l,a,2,y,1,plank);
   for(int x=-3;x>=-7;x--)part(l,a,x,0,2,b(x<=-5?"minecraft:iron_block":"minecraft:oak_planks"));
   glue(l,q(a,-2,0,2),q(a,-7,0,2));glue(l,q(a,-1,-1,1),q(a,0,0,2));
   glue(l,q(a,-2,0,2),q(a,0,0,2));glue(l,q(a,-2,-1,2),q(a,-2,0,2));glue(l,q(a,-2,-1,2),q(a,-2,-1,3));
   glue(l,q(a,-2,-3,2),q(a,-2,-1,2));glue(l,q(a,-2,-3,2),q(a,-1,-3,2));glue(l,q(a,-1,-3,2),q(a,-1,-2,1));glue(l,q(a,-1,-2,1),q(a,0,-2,1));
   glue(l,q(a,1,-8,1),q(a,1,-1,1));glue(l,q(a,1,-1,0),q(a,1,-1,1));glue(l,q(a,1,-7,1),q(a,2,-1,1));
   glue(l,q(a,2,-7,0),q(a,2,-7,1));glue(l,q(a,-1,-7,0),q(a,2,-7,0));glue(l,q(a,1,-7,-1),q(a,1,-7,0));
   glue(l,q(a,-1,-7,0),q(a,-1,-7,1));glue(l,q(a,-2,-7,1),q(a,-1,-7,1));glue(l,q(a,-2,-7,1),q(a,-2,-8,0));
   glue(l,q(a,-2,-8,0),q(a,1,-8,0));for(int y=-14;y< -8;y++)glue(l,q(a,2,y,1),q(a,2,y+1,1));
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
   
   if(be instanceof SwivelBearingBlockEntity sw)for(Leg a:legs)if(a.rollId.equals(sw.getSubLevelID()))a.roll=sw;
  }
  if(motor==null)throw new IllegalStateException("motor missing");reverseControl=motor.getBlockPos().east().above();
  for(Leg a:legs){
   if(a.roll==null)throw new IllegalStateException(a.name+" root bearing missing from chassis");
   a.rollControl=a.roll.getBlockPos().offset(1,1,-1);
   a.hip=findBearing(l,a.rollId,a.hipId);a.knee=findBearing(l,a.hipId,a.kneeId);
   a.hipControl=findClutch(l,a.rollId,false);a.kneeControl=findClutch(l,a.hipId,true);a.rollReverse=a.roll.getBlockPos().offset(3,1,1);a.hipReverse=findGearshift(l,a.rollId,false);a.kneeReverse=findGearshift(l,a.hipId,true);
   for(BlockPos at:List.of(a.rollControl,a.hipControl,a.kneeControl))if(!l.getBlockState(at).is(net.minecraft.world.level.block.Blocks.REDSTONE_BLOCK))throw new IllegalStateException(a.name+" missing redstone at "+at);
  }
  event("Chassis assembled and locked; one motor, four root pivots and eight nested pivots found");
 }
 SwivelBearingBlockEntity findBearing(ServerLevel l,UUID parent,UUID id){var part=SubLevelContainer.getContainer(l).getSubLevel(parent);for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity sw&&id.equals(sw.getSubLevelID()))return sw;throw new IllegalStateException("nested bearing "+id+" missing");}
 BlockPos findClutch(ServerLevel l,UUID parent,boolean north){var part=SubLevelContainer.getContainer(l).getSubLevel(parent);BlockPos found=null;Block clutch=b("create:clutch").getBlock();for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be.getBlockState().is(clutch)){if(found!=null)throw new IllegalStateException("multiple clutches in "+parent);found=north?be.getBlockPos().north():be.getBlockPos().south();}if(found==null)throw new IllegalStateException("clutch missing in "+parent);return found;}
 BlockPos findGearshift(ServerLevel l,UUID parent,boolean north){var part=SubLevelContainer.getContainer(l).getSubLevel(parent);BlockPos found=null;Block shift=b("create:gearshift").getBlock();for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be.getBlockState().is(shift)){if(found!=null)throw new IllegalStateException("multiple reversers in "+parent);found=north?be.getBlockPos().north():be.getBlockPos().south();}if(found==null)throw new IllegalStateException("reverser missing in "+parent);return found;}
 BlockPos reversal(Leg a,int axis){return axis==0?a.rollReverse:axis==1?a.hipReverse:a.kneeReverse;}
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
  Files.writeString(out.resolve("stand.csv"),line.append('\n'),StandardOpenOption.APPEND);}
 void releaseTickets(ServerLevel l)throws Exception{var c=SubLevelContainer.getContainer(l);int n=0;for(var sub:new ArrayList<>(c.getAllSubLevels()))if(c.removeForceLoadTicket(sub,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE))n++;event("Removed "+n+" forced tickets before saving");}
 double robotMass(ServerLevel l){var c=SubLevelContainer.getContainer(l);double sum=chassis.getMassTracker().getMass();for(Leg a:legs)for(UUID id:List.of(a.kneeId,a.hipId,a.rollId))sum+=((ServerSubLevel)c.getSubLevel(id)).getMassTracker().getMass();return sum;}
 void addBallast(ServerLevel l)throws Exception{double current=robotMass(l);double remaining=10000-current;int bed=(int)Math.floor(remaining/1000);remaining-=bed*1000;int iron=(int)Math.floor(remaining/4);remaining-=iron*4;int wool=(int)Math.round(remaining*4);if(bed<0||iron<0||wool<0||Math.abs(remaining-wool*.25)>.001)throw new IllegalStateException("cannot calibrate mass="+current);var root=legs.get(0).roll.getBlockPos();List<BlockPos> slots=new ArrayList<>();for(int x=2;x<=18;x++)for(int z=2;z<=14;z++){var at=root.offset(x,1,z);if(l.getBlockState(at).isAir())slots.add(at);}slots.sort(Comparator.comparingInt(at->(at.getX()-root.getX()-10)*(at.getX()-root.getX()-10)+(at.getZ()-root.getZ()-8)*(at.getZ()-root.getZ()-8)));if(slots.size()<bed+iron+wool)throw new IllegalStateException("insufficient ballast space");int i=0;for(int j=0;j<bed;j++)put(l,slots.get(i++),b("minecraft:bedrock"));for(int j=0;j<iron;j++)put(l,slots.get(i++),b("minecraft:iron_block"));for(int j=0;j<wool;j++)put(l,slots.get(i++),b("minecraft:white_wool"));event("Ballast base="+current+" bedrock="+bed+" iron="+iron+" wool="+wool);}
 dev.devce.rocketnautics.content.blocks.SputnikBlockEntity sputnik;dev.devce.websnodelib.api.WNode controller,operator;final boolean[] positive=new boolean[12],negative=new boolean[12];int overlapTicks;
 static final String[] COLORS={"white_wool","orange_wool","magenta_wool","light_blue_wool","yellow_wool","lime_wool","pink_wool","gray_wool","light_gray_wool","cyan_wool","purple_wool","blue_wool"};
 SwivelBearingBlockEntity onlyChild(ServerLevel l,UUID id){var part=SubLevelContainer.getContainer(l).getSubLevel(id);if(part==null)throw new IllegalStateException("missing body "+id);SwivelBearingBlockEntity found=null;for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity sw){if(found!=null)throw new IllegalStateException("multiple child bearings");found=sw;}if(found==null||!found.isAssembled()||found.getSubLevelID()==null)throw new IllegalStateException("missing child bearing");return found;}
 void recover(ServerLevel l)throws Exception{Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");var c=SubLevelContainer.getContainer(l);int motors=0;for(var sub:c.getAllSubLevels())for(var h:sub.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof CreativeMotorBlockEntity m){motors++;motor=m;chassis=sub;}if(motors!=1||chassis==null||motor.getSpeed()!=0)throw new IllegalStateException("one stopped motor required: "+motors);List<SwivelBearingBlockEntity> roots=new ArrayList<>();for(var h:chassis.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity sw)roots.add(sw);roots.sort(Comparator.comparingInt((SwivelBearingBlockEntity sw)->sw.getBlockPos().getZ()).thenComparingInt(sw->sw.getBlockPos().getX()));if(roots.size()!=4)throw new IllegalStateException("four roots required");for(int i=0;i<4;i++){Leg a=legs.get(i);a.roll=roots.get(i);a.rollId=a.roll.getSubLevelID();a.hip=onlyChild(l,a.rollId);a.hipId=a.hip.getSubLevelID();a.knee=onlyChild(l,a.hipId);a.kneeId=a.knee.getSubLevelID();a.rollControl=a.roll.getBlockPos().offset(1,1,-1);a.hipControl=findClutch(l,a.rollId,false);a.kneeControl=findClutch(l,a.hipId,true);a.rollReverse=a.roll.getBlockPos().offset(3,1,1);a.hipReverse=findGearshift(l,a.rollId,false);a.kneeReverse=findGearshift(l,a.hipId,true);var lower=c.getSubLevel(a.kneeId);var box=lower.getPlot().getBoundingBox();int slime=0,wood=0;for(var at:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ())){var st=l.getBlockState(at);if(st.is(net.minecraft.world.level.block.Blocks.SLIME_BLOCK)){slime++;a.footLocal=at.immutable();}if(st.is(net.minecraft.world.level.block.Blocks.OAK_PLANKS))wood++;}if(slime!=1||wood!=6)throw new IllegalStateException("bad foot "+a.name+" slime="+slime+" wood="+wood);}if(Math.abs(robotMass(l)-10000)>.001)throw new IllegalStateException("source mass wrong");event("Recovered 10 t, one stopped motor, 12 pivots and four slime feet");}
 void configureLink(ServerLevel l,BlockPos at,Direction facing,int i,boolean reverse){var state=b("create:redstone_link").setValue(BlockStateProperties.FACING,facing).setValue(com.simibubi.create.content.redstone.link.RedstoneLinkBlock.RECEIVER,true);l.setBlock(at,state,3);var be=l.getBlockEntity(at);if(!(be instanceof com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity))throw new IllegalStateException("link missing "+at);var tag=be.saveWithFullMetadata(l.registryAccess());tag.putBoolean("Transmitter",false);tag.put("FrequencyFirst",new net.minecraft.world.item.ItemStack(BuiltInRegistries.ITEM.get(ResourceLocation.parse("minecraft:"+COLORS[i]))).save(l.registryAccess()));tag.put("FrequencyLast",new net.minecraft.world.item.ItemStack(reverse?net.minecraft.world.item.Items.DIAMOND_BLOCK:net.minecraft.world.item.Items.NETHERITE_BLOCK).save(l.registryAccess()));be.loadWithComponents(tag,l.registryAccess());}
 int received(ServerLevel l,BlockPos p){var be=l.getBlockEntity(p);if(!(be instanceof com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity link))throw new IllegalStateException("receiver missing "+p);return link.getReceivedSignal();}
 void install(ServerLevel l)throws Exception{var root=legs.get(0).roll.getBlockPos();int removed=0;for(int x=2;x<=18;x++)for(int z=2;z<=14;z++){var at=root.offset(x,1,z);var st=l.getBlockState(at);if(st.is(net.minecraft.world.level.block.Blocks.BEDROCK)||st.is(net.minecraft.world.level.block.Blocks.IRON_BLOCK)||st.is(net.minecraft.world.level.block.Blocks.WHITE_WOOL)){l.setBlock(at,net.minecraft.world.level.block.Blocks.AIR.defaultBlockState(),3);removed++;}}event("Removed "+removed+" ballast blocks for recalibration");for(int i=0;i<4;i++){Leg a=legs.get(i);configureLink(l,a.rollControl,Direction.UP,i*3,false);configureLink(l,a.hipControl,Direction.SOUTH,i*3+1,false);configureLink(l,a.kneeControl,Direction.NORTH,i*3+2,false);configureLink(l,a.rollReverse,Direction.EAST,i*3,true);configureLink(l,a.hipReverse,Direction.SOUTH,i*3+1,true);configureLink(l,a.kneeReverse,Direction.NORTH,i*3+2,true);}var at=motor.getBlockPos().above();if(!l.getBlockState(at).isAir())throw new IllegalStateException("Sputnik location occupied: "+at);l.setBlock(at,b("rocketnautics:sputnik"),3);if(!(l.getBlockEntity(at) instanceof dev.devce.rocketnautics.content.blocks.SputnikBlockEntity sp))throw new IllegalStateException("Sputnik missing");sputnik=sp;controller=new dev.devce.websnodelib.api.WNode(ResourceLocation.parse("rocketnautics:lua_script"),"Independent 128 gait",20,40);controller.addInput("Enable",-1);controller.addInput("Start",-1);dev.devce.rocketnautics.registry.RocketNodes.setupLuaEvaluatorPublic(controller);String code=Files.readString(Path.of(System.getProperty("mintcraft.spot.controller")));controller.getCustomData().putString("code",code);sputnik.graph.addNode(controller);operator=new dev.devce.websnodelib.api.WNode(ResourceLocation.parse("rocketnautics:lua_script"),"Operator 128",20,400);operator.addOutput("Enable",-1);operator.addOutput("Start",-1);dev.devce.rocketnautics.registry.RocketNodes.setupLuaEvaluatorPublic(operator);String ui=Files.readString(Path.of(System.getProperty("mintcraft.spot.operator")));operator.getCustomData().putString("code",ui);sputnik.graph.addNode(operator);sputnik.graph.connect(operator.getId(),0,controller.getId(),0);sputnik.graph.connect(operator.getId(),1,controller.getId(),1);sputnik.setChanged();Files.writeString(out.resolve("controller.lua"),code);Files.writeString(out.resolve("operator.lua"),ui);event("Installed 24 Create redstone receivers and native Sputnik graph");}
 void input(String name,boolean on){var boxes=operator.getElements().stream().filter(e->e instanceof dev.devce.websnodelib.api.elements.WCheckbox).map(e->(dev.devce.websnodelib.api.elements.WCheckbox)e).toList();if(boxes.size()!=2)throw new IllegalStateException("operator checkboxes not ready");boxes.get(name.equals("Enable")?0:1).setChecked(on);}
 void sampleWireless(ServerLevel l)throws Exception{StringBuilder row=new StringBuilder().append(tick).append(',').append(motor.getSpeed());int active=0;for(int i=0;i<12;i++){Leg a=legs.get(i/3);int axis=i%3;int gate=received(l,control(a,axis)),rev=received(l,reversal(a,axis));var clutchAt=axis==0?control(a,axis).below():axis==1?control(a,axis).north():control(a,axis).south();var cs=l.getBlockState(clutchAt);boolean powered=cs.hasProperty(BlockStateProperties.POWERED)&&cs.getValue(BlockStateProperties.POWERED);double axial=joint(a,axis).getSpeed();double speed=joint(a,axis).getExtraKinetics().getSpeed();if(Math.abs(speed)>.01){active++;if(speed>0)positive[i]=true;else negative[i]=true;}row.append(',').append(gate).append(',').append(rev).append(',').append(powered).append(',').append(axial).append(',').append(speed);}if(active>1)overlapTicks++;Files.writeString(out.resolve("wireless.csv"),row.append('\n'),StandardOpenOption.APPEND);}
 double baselineY; boolean halted;
 void tick(ServerTickEvent.Post e){var server=e.getServer();var l=server.overworld();tick++;try{
  if(tick==20)for(int x=1;x<=4;x++)for(int z=1;z<=4;z++)l.setChunkForced(x,z,true);
  if(tick==200){recover(l);install(l);for(int x=16;x<=72;x++)for(int z=-240;z<=100;z++)l.setBlock(new BlockPos(x,165,z),b("minecraft:stone"),3);event("Flat stone floor, z=-240..100; no obstacles");}
  if(tick==220)addBallast(l);
  if(tick==245){if(Math.abs(robotMass(l)-10000)>.001)throw new IllegalStateException("mass wrong");for(int i=0;i<12;i++){Leg a=legs.get(i/3);if(received(l,control(a,i%3))!=15)throw new IllegalStateException("unsafe gate");}Files.writeString(out.resolve("stand.csv"),"tick,phase,x,y,z,qx,qy,qz,qw,locked,fl_x,fl_y,fl_z,fr_x,fr_y,fr_z,rl_x,rl_y,rl_z,rr_x,rr_y,rr_z\n");StringBuilder h=new StringBuilder("tick,motor_rpm");for(Leg a:legs)for(String n:List.of("roll","hip","knee"))h.append(',').append(a.name).append('_').append(n).append("_gate,").append(a.name).append('_').append(n).append("_reverse,").append(a.name).append('_').append(n).append("_clutch_powered,").append(a.name).append('_').append(n).append("_axial_rpm,").append(a.name).append('_').append(n).append("_rpm");Files.writeString(out.resolve("wireless.csv"),h.append('\n'));}
  if(tick==250){var c=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);for(Leg a:legs)for(UUID id:List.of(a.kneeId,a.hipId,a.rollId)){var sub=c.getSubLevel(id);if(staff.isLocked(sub))staff.removeLock(sub);}if(!staff.isLocked(chassis))throw new IllegalStateException("expected locked chassis");staff.removeLock(chassis);event("Released chassis and legs; motor stopped");}
  if(tick==245)Files.writeString(out.resolve("telemetry.csv"),"tick,running,cycle,phase,clock_fault,tilt_guard,pose_valid,yaw_error,pitch,yaw,roll\n");
  if(tick>=390&&tick<=900){sampleWireless(l);StringBuilder t=new StringBuilder().append(tick);for(String n:List.of("Running","Cycle","Phase","Clock fault","Tilt guard","Pose valid","Yaw error","Probe pitch","Probe yaw","Probe roll"))t.append(',').append(controller.getOutputs().stream().filter(pin->pin.getName().equals(n)).findFirst().map(pin->pin.getValueAsString()).orElse("missing"));Files.writeString(out.resolve("telemetry.csv"),t.append('\n'),StandardOpenOption.APPEND);}

  if(tick>=250&&tick<=1050)recordStand(l,tick<360?"settle":"gait");
  if(tick==350){baselineY=chassis.logicalPose().position().y();var q=chassis.logicalPose().orientation();double tilt=Math.toDegrees(Math.acos(Math.max(-1,Math.min(1,1-2*(q.x()*q.x()+q.z()*q.z())))));event("Settled y="+baselineY+" tilt="+tilt);if(tilt>10)throw new IllegalStateException("unstable before gait");}
  if(tick==360){motor.generatedSpeed.setValue(128);event("Motor enabled 128 rpm");}
  if(tick==380)input("Enable",true);
  if(tick==400)input("Start",true);
  if(tick==401)input("Start",false);
  if(tick>=360&&!halted){var q=chassis.logicalPose().orientation();double tilt=Math.toDegrees(Math.acos(Math.max(-1,Math.min(1,1-2*(q.x()*q.x()+q.z()*q.z())))));double drop=baselineY-chassis.logicalPose().position().y();if(tilt>15||drop>1.5){halted=true;input("Enable",false);motor.generatedSpeed.setValue(0);event("SAFETY STOP tilt="+tilt+" drop="+drop);}}
  if(tick==500&&Double.parseDouble(System.getProperty("mintcraft.spot.lateralDv","0"))!=0){double dv=Double.parseDouble(System.getProperty("mintcraft.spot.lateralDv"));double mass=chassis.getMassTracker().getMass();dev.ryanhcode.sable.api.physics.handle.RigidBodyHandle.of(chassis).applyLinearAndAngularImpulse(new org.joml.Vector3d(mass*dv,0,0),new org.joml.Vector3d());event("Applied lateral impulse: chassis nominal delta_v="+dv+" mass="+mass);}
  if(tick==900){if(!halted){input("Enable",false);motor.generatedSpeed.setValue(0);event("Timed gait complete");}event("Final mass="+robotMass(l));}
  if(tick==1050){sputnik.setChanged();Files.writeString(out.resolve("complete.txt"),"Unheld flat-ground trial; inspect events and stand.csv for outcome.\n");server.halt(false);return;}
 }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}}
}
