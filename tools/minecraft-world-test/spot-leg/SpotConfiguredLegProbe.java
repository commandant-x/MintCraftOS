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
public class SpotConfiguredLegProbe {
 final String selected="hip_roll"; final int length=7; int tick;final BlockPos base=new BlockPos(32,180,32);final Path out=Path.of("mintcraft-spot-leg");
 final List<UUID> childIds=new ArrayList<>(); BlockPos hipControl,kneeControl;
 public SpotConfiguredLegProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockPos p(int x,int y,int z){return base.offset(x,y,z);} BlockState b(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 void set(ServerLevel l,int x,int y,int z,BlockState s){l.setBlock(p(x,y,z),s,3);}
 void glue(ServerLevel l,BlockPos a,BlockPos b){l.addFreshEntity(new SuperGlueEntity(l,SuperGlueEntity.span(a,b)));}
 void setup(ServerLevel l)throws Exception{
  l.setChunkForced(base.getX()>>4,base.getZ()>>4,true);Files.createDirectories(out);
  Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");
  var cfg=dev.simulated_team.simulated.service.SimConfigService.INSTANCE.server().physics;
  Files.writeString(out.resolve("runtime-config.txt"),"swivel_stiffness="+cfg.swivelBearingStiffness.get()+"\nswivel_damping="+cfg.swivelBearingDamping.get()+"\n");
  var plank=b("minecraft:oak_planks");var bearing=b("simulated:swivel_bearing");
  set(l,0,0,-2,b("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.SOUTH));
  ((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,-2))).generatedSpeed.setValue(0);
  set(l,0,0,-1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,1,0,-1,b("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,0,-1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,2,0,0,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,1,1,-1,b("minecraft:redstone_block"));
  set(l,1,0,0,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,0,0,0,bearing.setValue(BlockStateProperties.FACING,Direction.SOUTH));
  set(l,0,0,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,0,0,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-1,0,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,-1,0,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-1,-1,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,-2,0,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,-2,-1,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,-1,-1,2,b("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,-1,-1,3,b("minecraft:redstone_block"));
  set(l,0,-1,2,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,0,-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  for(int y=-1;y>=-length;y--)set(l,1,y,1,plank);
  set(l,1,-1,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,1,-1,0,plank);
  set(l,2,-1,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  for(int y=-2;y>=-length+1;y--)set(l,2,y,1,b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,2,-length,1,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,-length,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y));
  set(l,3,-length,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,3,-length-1,2,b("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
  set(l,2,-length-1,2,b("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,2,-length-1,3,b("minecraft:redstone_block"));
  set(l,1,-length-1,2,b("create:cogwheel").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  set(l,1,-length-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  for(int y=-length-1;y>=-2*length;y--)set(l,2,y,1,plank);
  glue(l,p(-1,-1,1),p(0,0,2));glue(l,p(-2,-1,2),p(-1,0,2));glue(l,p(-1,-1,2),p(-1,-1,3));glue(l,p(1,-length-1,1),p(1,-1,1));glue(l,p(1,-1,0),p(1,-1,1));
  glue(l,p(1,-length,1),p(2,-1,1));glue(l,p(2,-length,1),p(2,-length,2));
  glue(l,p(2,-length,2),p(3,-length,2));glue(l,p(3,-length,2),p(3,-length-1,2));
  glue(l,p(3,-length-1,2),p(1,-length-1,2));glue(l,p(2,-length-1,2),p(2,-length-1,3));glue(l,p(2,-2*length,1),p(2,-length-1,1));
  event("Placed one creative motor, three swivel bearings and two segments of "+length+" blocks each; motor speed 0; three redstone clutches installed, initially powered and disengaged");
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
  var staff=PhysicsStaffServerHandler.get(l);if(!staff.isLocked(sub))staff.toggleLock(id);childIds.add(id);event("Assembled "+name+" axis="+bearing.getBlockState().getValue(BlockStateProperties.FACING).getAxis()+" child="+id);
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
  if(plankCount[0]!=length||plankCount[1]!=length)throw new IllegalStateException("Segment lengths differ from seven: "+Arrays.toString(plankCount));
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
  ((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,-2))).generatedSpeed.setValue(4);
  event("Released child bodies and set the single creative motor to 4 RPM; no impulse applied");
 }
 void sampleDrive(ServerLevel l)throws Exception{
  var root=(SwivelBearingBlockEntity)l.getBlockEntity(p(0,0,0));
  var motor=(CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,-2));
  SwivelBearingBlockEntity hip=null,knee=null;
  for(var craft:SubLevelContainer.getContainer(l).getAllSubLevels())for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity b){if(childIds.get(1).equals(b.getSubLevelID()))hip=b;if(childIds.get(0).equals(b.getSubLevelID()))knee=b;}
  if(hip==null||knee==null)throw new IllegalStateException("hip or knee pivot not found");
  Files.writeString(out.resolve("drive.csv"),tick+","+motor.getSpeed()+","+root.getSpeed()+","+root.getExtraKinetics().getSpeed()+","+root.getTargetAngleDegrees()+","+hip.getExtraKinetics().getSpeed()+","+hip.getTargetAngleDegrees()+","+knee.getExtraKinetics().getSpeed()+","+knee.getTargetAngleDegrees()+"\n",StandardOpenOption.APPEND);
 }
 void discoverControls(ServerLevel l)throws Exception{
  var c=SubLevelContainer.getContainer(l);var clutch=BuiltInRegistries.BLOCK.get(ResourceLocation.parse("create:clutch"));
  for(int i=1;i<=2;i++){
   var craft=c.getSubLevel(childIds.get(i));BlockPos found=null;
   for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be.getBlockState().is(clutch)){if(found!=null)throw new IllegalStateException("multiple clutches in body "+i);found=be.getBlockPos().immutable();}
   if(found==null)throw new IllegalStateException("missing clutch in body "+i);
   BlockPos control=found.south();if(!l.getBlockState(control).is(net.minecraft.world.level.block.Blocks.REDSTONE_BLOCK))throw new IllegalStateException("redstone control missing at "+control);
   if(i==1)kneeControl=control;else hipControl=control;event("Found redstone control for "+(i==1?"knee":"hip_pitch")+" at "+control);
  }
 }
 void power(ServerLevel l,BlockPos control,boolean powered,String label)throws Exception{
  l.setBlock(control,powered?b("minecraft:redstone_block"):net.minecraft.world.level.block.Blocks.AIR.defaultBlockState(),3);
  event("Redstone "+label+" set "+(powered?"ON (clutch disengaged)":"OFF (clutch engaged)"));
 }
 void tick(ServerTickEvent.Post e){MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);
   if(tick==80)assemble(l,p(1,-length-1,1),"knee");
   if(tick==120)assemble(l,p(0,-1,1),"hip_pitch");
   if(tick==160)assemble(l,p(0,0,0),"hip_roll");
   if(tick==220){audit(l);if(selected.equals("none")){Files.writeString(out.resolve("complete.txt"),"Three pivot blocks and child bodies retained while staff-locked. No joint movement or walking qualification.\n");server.halt(false);}else Files.writeString(out.resolve("poses.csv"),"tick,phase,knee_qx,knee_qy,knee_qz,knee_qw,knee_locked,hip_pitch_qx,hip_pitch_qy,hip_pitch_qz,hip_pitch_qw,hip_pitch_locked,hip_roll_qx,hip_roll_qy,hip_roll_qz,hip_roll_qw,hip_roll_locked\n");}
   if(tick==225)discoverControls(l);
   if(tick==230){Files.writeString(out.resolve("drive.csv"),"tick,motor_rpm,axial_rpm,cog_rpm,target_degrees,hip_cog_rpm,hip_target_degrees,knee_cog_rpm,knee_target_degrees\n");recordPoses(l,"before_drive");drive(l);}
   if(tick==260)power(l,p(1,1,-1),false,"hip_roll");
   if(tick==300)power(l,p(1,1,-1),true,"hip_roll");
   if(tick==320)power(l,hipControl,false,"hip_pitch");
   if(tick==360)power(l,hipControl,true,"hip_pitch");
   if(tick==380)power(l,kneeControl,false,"knee");
   if(tick==420)power(l,kneeControl,true,"knee");
   if(tick==480){((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,-2))).generatedSpeed.setValue(0);event("Motor commanded to stop");}
   if(tick>=240&&tick<=500&&tick%10==0){recordPoses(l,"after_drive");sampleDrive(l);}
   if(tick==500){Files.writeString(out.resolve("complete.txt"),"Three redstone clutch phases measured without impulse; inspect speeds and relative poses. No walking qualification.\n");server.halt(false);}

  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
