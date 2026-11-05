package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import com.simibubi.create.content.contraptions.glue.SuperGlueEntity;
import java.nio.file.*;
import java.util.*;

/** Experimental one-leg, three-pivot mechanical construction. No walking claim. */
@Mod("mintcraft_probe")
public class RebuiltLegSharedReductionProbe {
 final String selected="hip_roll"; final int length=7; int tick,glueWait;final BlockPos base=new BlockPos(96,180,96);final Path out=Path.of("mintcraft-rebuilt-leg-reduction");
 final List<UUID> childIds=new ArrayList<>(); BlockPos hipControl,kneeControl,hipReverse,kneeReverse;
 public RebuiltLegSharedReductionProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockPos p(int x,int y,int z){return base.offset(x,y,z);} BlockState b(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 void set(ServerLevel l,int x,int y,int z,BlockState s){l.setBlock(p(x,y,z),s,3);}
 void glue(ServerLevel l,BlockPos a,BlockPos b){if(!l.addFreshEntity(new SuperGlueEntity(l,SuperGlueEntity.span(a,b))))throw new IllegalStateException("glue spawn failed "+a+" -> "+b);}
 void setup(ServerLevel l)throws Exception{
  l.setChunkForced(base.getX()>>4,base.getZ()>>4,true);Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");
  var plank=b("minecraft:oak_planks");var bearing=b("simulated:swivel_bearing");
  set(l,2,2,-4,b("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.SOUTH));
  // Two upstream 2:1 stages feed the whole leg at 32 RPM from one 128 RPM motor.
  set(l,2,2,-3,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,1,-3,b("create:large_cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,1,-2,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,0,0,-2,b("create:large_cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  ((CreativeMotorBlockEntity)l.getBlockEntity(p(2,2,-4))).generatedSpeed.setValue(0);
  // Root bearing carries a fast axial shaft. Its rotary cog has its own 2:1 reducer.
  set(l,0,0,-1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,1,0,-1,b("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,0,-1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,2,0,0,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,1,0,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,1,1,b("create:gearshift").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,2,1,2,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,0,2,b("create:large_cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,0,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,0,0,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,1,-1,b("minecraft:redstone_block"));
  set(l,0,0,0,bearing.setValue(BlockStateProperties.FACING,Direction.SOUTH));
  // Hip-pitch reducer is inside the roll body; control block south of its clutch.
  set(l,0,0,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,0,0,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-1,0,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-1,0,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-1,-1,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,-2,0,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,-2,-1,2,b("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-2,-1,3,b("minecraft:redstone_block"));
  set(l,-2,-2,2,b("create:gearshift").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-2,-3,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,-1,-3,2,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-1,-2,1,b("create:large_cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,0,-2,1,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,0,-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  // Knee reducer is carried by the upper segment; control north of its clutch.
  for(int y=-1;y>=-length;y--)set(l,1,y,1,plank);
  set(l,1,-1,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.X));set(l,1,-1,0,plank);
  set(l,2,-1,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  for(int y=-2;y>=-length+1;y--)set(l,2,y,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,2,-length,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,-length,0,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,1,-length,0,b("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,1,-length,-1,b("minecraft:redstone_block"));
  set(l,0,-length,0,b("create:gearshift").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-1,-length,0,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-1,-length,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-2,-length,1,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-2,-length-1,0,b("create:large_cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-1,-length-1,0,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,0,-length-1,0,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,1,-length-1,0,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,1,-length-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  for(int y=-length-1;y>=-2*length;y--)set(l,2,y,1,y==-2*length?b("minecraft:slime_block"):plank);
  glue(l,p(-1,-1,1),p(0,0,2));glue(l,p(-2,0,2),p(0,0,2));glue(l,p(-2,-1,2),p(-2,0,2));glue(l,p(-2,-1,2),p(-2,-1,3));
  glue(l,p(-2,-3,2),p(-2,-1,2));glue(l,p(-2,-3,2),p(-1,-3,2));glue(l,p(-1,-3,2),p(-1,-2,1));glue(l,p(-1,-2,1),p(0,-2,1));
  glue(l,p(1,-length-1,1),p(1,-1,1));glue(l,p(1,-1,0),p(1,-1,1));glue(l,p(1,-length,1),p(2,-1,1));
  glue(l,p(2,-length,0),p(2,-length,1));glue(l,p(-1,-length,0),p(2,-length,0));glue(l,p(1,-length,-1),p(1,-length,0));
  glue(l,p(-1,-length,0),p(-1,-length,1));glue(l,p(-2,-length,1),p(-1,-length,1));glue(l,p(-2,-length,1),p(-2,-length-1,0));
  glue(l,p(-2,-length-1,0),p(1,-length-1,0));for(int y=-2*length;y< -length-1;y++)glue(l,p(2,y,1),p(2,y+1,1));
  event("Built one motor, shared 4:1 input reducer, three pivot branches with independent 2:1 reducers, clutches and reversers; motor initially stopped");
 }
 void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 void assemble(ServerLevel l,BlockPos pos,String name)throws Exception{
  var be=l.getBlockEntity(pos);if(!(be instanceof SwivelBearingBlockEntity bearing))throw new IllegalStateException(name+" bearing missing at "+pos+": "+be);
  if(Boolean.getBoolean("mintcraft.spot.unlocked")){
   var f=bearing.getClass().getDeclaredField("lockedDefaultOption");f.setAccessible(true);
   var setting=(com.simibubi.create.foundation.blockEntity.behaviour.scrollValue.ScrollOptionBehaviour<?>)f.get(bearing);
   if(setting==null)throw new IllegalStateException("Pivot lock setting not initialized");setting.setValue(3);
  }
  bearing.assemble();if(!bearing.isAssembled()||bearing.getSubLevelID()==null)throw new IllegalStateException(name+" assembly failed: "+bearing.getLastAssemblyException());
  UUID id=bearing.getSubLevelID();var sub=(ServerSubLevel)SubLevelContainer.getContainer(l).getSubLevel(id);if(sub==null)throw new IllegalStateException(name+" child absent");
  SubLevelContainer.getContainer(l).addForceLoadTicket(sub,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE);
  var staff=PhysicsStaffServerHandler.get(l);if(!staff.isLocked(sub))staff.toggleLock(id);childIds.add(id);event("Assembled "+name+" axis="+bearing.getBlockState().getValue(BlockStateProperties.FACING).getAxis()+" child="+id);for(UUID current:childIds){var body=SubLevelContainer.getContainer(l).getSubLevel(current);var box=body.getPlot().getBoundingBox();int wood=0;for(var at:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ()))if(l.getBlockState(at).is(net.minecraft.world.level.block.Blocks.OAK_PLANKS))wood++;event("DIAGNOSTIC after="+name+" child="+current+" wood="+wood+" box="+box);}int remaining=0;for(int y=-length-1;y>=-2*length;y--)if(l.getBlockState(p(2,y,1)).is(net.minecraft.world.level.block.Blocks.OAK_PLANKS))remaining++;event("DIAGNOSTIC overworld_lower_planks="+remaining);
 }
 void audit(ServerLevel l)throws Exception{
  var container=SubLevelContainer.getContainer(l);int count=0;StringBuilder report=new StringBuilder();var root=l.getBlockEntity(p(0,0,0));
  if(root instanceof SwivelBearingBlockEntity b){count++;report.append("root axis=").append(b.getBlockState().getValue(BlockStateProperties.FACING).getAxis()).append(" assembled=").append(b.isAssembled()).append('\n');}
  int parts=0;for(var craft:container.getAllSubLevels())for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity b){count++;report.append("child axis=").append(b.getBlockState().getValue(BlockStateProperties.FACING).getAxis()).append(" assembled=").append(b.isAssembled()).append(" body=").append(craft.getUniqueId()).append('\n');}
  for(UUID id:childIds)if(container.getSubLevel(id)!=null)parts++;
  int[] plankCount=new int[2];for(int i=0;i<2;i++){
   var part=container.getSubLevel(childIds.get(i));if(part==null)throw new IllegalStateException("missing segment");
   var box=part.getPlot().getBoundingBox();
   for(var at:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ()))if(l.getBlockState(at).is(net.minecraft.world.level.block.Blocks.OAK_PLANKS))plankCount[i]++;
  }
  report.append("lower_planks=").append(plankCount[0]).append(" upper_planks=").append(plankCount[1]).append('\n');
  if(plankCount[0]!=length-1||plankCount[1]!=length)throw new IllegalStateException("Segment lengths differ from seven: "+Arrays.toString(plankCount));
  report.append("pivot_count=").append(count).append(" retained_children=").append(parts).append(" creative_motor_count=1 motor_rpm=0\n");Files.writeString(out.resolve("audit.txt"),report);event("AUDIT pivots="+count+" children="+parts);
  if(count!=3||parts!=3)throw new IllegalStateException("Three-joint assembly not retained");

 }
 void recordPoses(ServerLevel l,String phase)throws Exception{
  var container=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);
  StringBuilder line=new StringBuilder().append(tick).append(',').append(phase);
  for(UUID id:childIds){var sub=(ServerSubLevel)container.getSubLevel(id);if(sub==null)throw new IllegalStateException("body disappeared");var q=sub.logicalPose().orientation();line.append(',').append(q.x()).append(',').append(q.y()).append(',').append(q.z()).append(',').append(q.w()).append(',').append(staff.isLocked(sub));}
  Files.writeString(out.resolve("poses.csv"),line.append('\n'),StandardOpenOption.APPEND);
 }
 void drive(ServerLevel l)throws Exception{
  var container=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);
  for(UUID id:childIds){var sub=(ServerSubLevel)container.getSubLevel(id);if(staff.isLocked(sub))staff.removeLock(sub);}
  ((CreativeMotorBlockEntity)l.getBlockEntity(p(2,2,-4))).generatedSpeed.setValue(Integer.getInteger("mintcraft.spot.motorRpm",128));
  event("Released child bodies and set the single creative motor with independent 2:1 reducers; no impulse applied");
 }
 void sampleDrive(ServerLevel l)throws Exception{
  var root=(SwivelBearingBlockEntity)l.getBlockEntity(p(0,0,0));
  var motor=(CreativeMotorBlockEntity)l.getBlockEntity(p(2,2,-4));
  SwivelBearingBlockEntity hip=null,knee=null;
  for(var craft:SubLevelContainer.getContainer(l).getAllSubLevels())for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity b){if(childIds.get(1).equals(b.getSubLevelID()))hip=b;if(childIds.get(0).equals(b.getSubLevelID()))knee=b;}
  if(hip==null||knee==null)throw new IllegalStateException("hip or knee pivot not found");
  Files.writeString(out.resolve("drive.csv"),tick+","+motor.getSpeed()+","+root.getSpeed()+","+root.getExtraKinetics().getSpeed()+","+root.getTargetAngleDegrees()+","+hip.getExtraKinetics().getSpeed()+","+hip.getTargetAngleDegrees()+","+knee.getExtraKinetics().getSpeed()+","+knee.getTargetAngleDegrees()+"\n",StandardOpenOption.APPEND);
 }
 void sampleKneeNetwork(ServerLevel l)throws Exception{
  SwivelBearingBlockEntity knee=null,hip=null;for(var craft:SubLevelContainer.getContainer(l).getAllSubLevels())for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity sw){if(childIds.get(0).equals(sw.getSubLevelID()))knee=sw;if(childIds.get(1).equals(sw.getSubLevelID()))hip=sw;}if(knee==null||hip==null)throw new IllegalStateException("diagnostic bearing missing");
  var base=knee.getBlockPos();int[][] offsets={{1,1,0},{1,1,-1},{0,1,-1},{-1,1,-1},{-1,1,0},{-2,1,0},{-2,0,-1},{-1,0,-1},{0,0,-1}};String[] names={"source_gearbox","turn_gearbox","clutch","in_gearbox","side_gearbox","small_cog","large_cog","shaft","output_cog"};StringBuilder line=new StringBuilder().append(tick).append(',').append(hip.getSpeed()).append(',').append(knee.getSpeed()).append(',').append(knee.getExtraKinetics().getSpeed());for(int i=0;i<offsets.length;i++){var at=base.offset(offsets[i][0],offsets[i][1],offsets[i][2]);var be=l.getBlockEntity(at);double speed=be instanceof com.simibubi.create.content.kinetics.base.KineticBlockEntity k?k.getSpeed():Double.NaN;line.append(',').append(names[i]).append(':').append(net.minecraft.core.registries.BuiltInRegistries.BLOCK.getKey(l.getBlockState(at).getBlock())).append(':').append(speed);}Files.writeString(out.resolve("knee-network.csv"),line.append('\n'),StandardOpenOption.CREATE,StandardOpenOption.APPEND);
 }
 void discoverControls(ServerLevel l)throws Exception{
  var c=SubLevelContainer.getContainer(l);var clutch=BuiltInRegistries.BLOCK.get(ResourceLocation.parse("create:clutch"));
  for(int i=1;i<=2;i++){
   var craft=c.getSubLevel(childIds.get(i));BlockPos found=null;
   for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be.getBlockState().is(clutch)){if(found!=null)throw new IllegalStateException("multiple clutches in body "+i);found=be.getBlockPos().immutable();}
   if(found==null)throw new IllegalStateException("missing clutch in body "+i);
   BlockPos control=i==1?found.north():found.south();if(!l.getBlockState(control).is(net.minecraft.world.level.block.Blocks.REDSTONE_BLOCK))throw new IllegalStateException("redstone control missing at "+control);
   if(i==1)kneeControl=control;else hipControl=control;event("Found redstone control for "+(i==1?"knee":"hip_pitch")+" at "+control);
   BlockPos reverse=null;var shift=BuiltInRegistries.BLOCK.get(ResourceLocation.parse("create:gearshift"));for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be.getBlockState().is(shift)){if(reverse!=null)throw new IllegalStateException("duplicate reverser");reverse=be.getBlockPos().immutable();}if(reverse==null)throw new IllegalStateException("missing reverser in body "+i);if(i==1)kneeReverse=reverse.north();else hipReverse=reverse.south();
  }
 }
 void power(ServerLevel l,BlockPos control,boolean powered,String label)throws Exception{
  l.setBlock(control,powered?b("minecraft:redstone_block"):net.minecraft.world.level.block.Blocks.AIR.defaultBlockState(),3);
  event("Redstone "+label+" set "+(powered?"ON (clutch disengaged)":"OFF (clutch engaged)"));
 }
 void tick(ServerTickEvent.Post e){MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);
   if(tick==70){boolean ready=true;for(int y=-8;y>=-13;y--)if(!com.simibubi.create.content.contraptions.glue.SuperGlueEntity.isGlued(l,p(2,y,1),Direction.DOWN,new HashSet<>()))ready=false;if(!ready){if(++glueWait>400)throw new IllegalStateException("lower-leg glue did not become available");tick--;return;}event("All six lower-leg glue links available after "+glueWait+" wait ticks");}
   if(tick==80)assemble(l,p(1,-length-1,1),"knee");
   if(tick==120)assemble(l,p(0,-1,1),"hip_pitch");
   if(tick==160)assemble(l,p(0,0,0),"hip_roll");
   if(tick==220){audit(l);if(selected.equals("none")){Files.writeString(out.resolve("complete.txt"),"Three pivot blocks and child bodies retained while staff-locked. No joint movement or walking qualification.\n");server.halt(false);}else Files.writeString(out.resolve("poses.csv"),"tick,phase,knee_qx,knee_qy,knee_qz,knee_qw,knee_locked,hip_pitch_qx,hip_pitch_qy,hip_pitch_qz,hip_pitch_qw,hip_pitch_locked,hip_roll_qx,hip_roll_qy,hip_roll_qz,hip_roll_qw,hip_roll_locked\n");}
   if(tick==225)discoverControls(l);
   if(tick==230){Files.writeString(out.resolve("drive.csv"),"tick,motor_rpm,axial_rpm,cog_rpm,target_degrees,hip_cog_rpm,hip_target_degrees,knee_cog_rpm,knee_target_degrees\n");recordPoses(l,"before_drive");drive(l);}
   if(tick==250)Files.writeString(out.resolve("foot.csv"),"tick,x,y,z\n");
   if(tick>=250&&tick<=430){var lower=SubLevelContainer.getContainer(l).getSubLevel(childIds.get(0));var box=lower.getPlot().getBoundingBox();BlockPos foot=null;for(var at:BlockPos.betweenClosed(box.minX(),box.minY(),box.minZ(),box.maxX(),box.maxY(),box.maxZ()))if(l.getBlockState(at).is(Blocks.SLIME_BLOCK))foot=at.immutable();if(foot==null)throw new IllegalStateException("slime foot missing");var v=lower.logicalPose().transformPosition(new org.joml.Vector3d(foot.getX()+.5,foot.getY(),foot.getZ()+.5),new org.joml.Vector3d());Files.writeString(out.resolve("foot.csv"),tick+","+v.x()+","+v.y()+","+v.z()+"\n",StandardOpenOption.APPEND);recordPoses(l,"sweep");sampleDrive(l);}
   if(Boolean.getBoolean("mintcraft.spot.balanceHip")&&tick==245){l.setBlock(hipReverse,Blocks.REDSTONE_BLOCK.defaultBlockState(),3);event("Hip counter-rotation selected");}
   if(Boolean.getBoolean("mintcraft.spot.balanceHip")&&(tick==260||tick==272))power(l,hipControl,false,"hip counter");
   if(Boolean.getBoolean("mintcraft.spot.balanceHip")&&(tick==262||tick==274))power(l,hipControl,true,"hip counter");
   if(tick==260||tick==272||tick==284||tick==296)power(l,kneeControl,false,"knee flex");
   if(tick==262||tick==274||tick==286||tick==298)power(l,kneeControl,true,"knee flex");
   if(tick==320){l.setBlock(kneeReverse,Blocks.REDSTONE_BLOCK.defaultBlockState(),3);if(Boolean.getBoolean("mintcraft.spot.balanceHip"))l.setBlock(hipReverse,Blocks.AIR.defaultBlockState(),3);event("knee extension direction selected");}
   if(Boolean.getBoolean("mintcraft.spot.balanceHip")&&(tick==330||tick==342))power(l,hipControl,false,"hip return");
   if(Boolean.getBoolean("mintcraft.spot.balanceHip")&&(tick==332||tick==344))power(l,hipControl,true,"hip return");
   if(tick==330||tick==342||tick==354||tick==366)power(l,kneeControl,false,"knee extend");
   if(tick==332||tick==344||tick==356||tick==368)power(l,kneeControl,true,"knee extend");
   if(tick==420){((CreativeMotorBlockEntity)l.getBlockEntity(p(2,2,-4))).generatedSpeed.setValue(0);event("Motor stopped");}
   if(tick==430){Files.writeString(out.resolve("complete.txt"),"Completed isolated unloaded knee flexion-extension sweep; inspect physical poses and foot position.\n");server.halt(false);return;}

  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
