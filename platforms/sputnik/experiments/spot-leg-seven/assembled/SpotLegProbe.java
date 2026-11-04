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
public class SpotLegProbe {
 final String selected=System.getProperty("mintcraft.spot.legAxis","none"); final int length=7; int tick;final BlockPos base=new BlockPos(32,180,32);final Path out=Path.of("mintcraft-spot-leg");
 final List<UUID> childIds=new ArrayList<>();
 public SpotLegProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockPos p(int x,int y,int z){return base.offset(x,y,z);} BlockState b(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 void set(ServerLevel l,int x,int y,int z,BlockState s){l.setBlock(p(x,y,z),s,3);}
 void glue(ServerLevel l,BlockPos a,BlockPos b){l.addFreshEntity(new SuperGlueEntity(l,SuperGlueEntity.span(a,b)));}
 void setup(ServerLevel l)throws Exception{
  l.setChunkForced(base.getX()>>4,base.getZ()>>4,true);Files.createDirectories(out);
  Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");
  var plank=b("minecraft:oak_planks");var bearing=b("simulated:swivel_bearing");
  set(l,0,0,-1,b("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.SOUTH));
  ((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,-1))).generatedSpeed.setValue(0);
  set(l,0,0,0,bearing.setValue(BlockStateProperties.FACING,Direction.SOUTH));
  set(l,0,0,1,plank);set(l,0,-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  for(int y=-1;y>=-length;y--)set(l,1,y,1,plank);
  set(l,1,-length-1,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  for(int y=-length-1;y>=-2*length;y--)set(l,2,y,1,plank);
  glue(l,p(0,-1,1),p(0,0,1));glue(l,p(1,-length-1,1),p(1,-1,1));glue(l,p(2,-2*length,1),p(2,-length-1,1));
  event("Placed one creative motor, three swivel bearings and two segments of "+length+" blocks each; motor speed 0");
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
 void impulse(ServerLevel l)throws Exception{
  int which=switch(selected){case "knee"->0;case "hip_pitch"->1;case "hip_roll"->2;default->throw new IllegalStateException("Unknown axis "+selected);};
  var container=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);
  for(int i=0;i<=which;i++){var sub=(ServerSubLevel)container.getSubLevel(childIds.get(i));if(sub==null)throw new IllegalStateException("missing child");if(staff.isLocked(sub))staff.removeLock(sub);}
  var sub=(ServerSubLevel)container.getSubLevel(childIds.get(which));var angular=which==2?new org.joml.Vector3d(0,0,.75):new org.joml.Vector3d(.75,0,0);
  dev.ryanhcode.sable.api.physics.handle.RigidBodyHandle.of(sub).addLinearAndAngularVelocity(new org.joml.Vector3d(),angular);
  event("Applied test-only angular velocity on "+selected+"; no motor-driven movement claimed");
 }
 void tick(ServerTickEvent.Post e){MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);
   if(tick==80)assemble(l,p(1,-length-1,1),"knee");
   if(tick==120)assemble(l,p(0,-1,1),"hip_pitch");
   if(tick==160)assemble(l,p(0,0,0),"hip_roll");
   if(tick==220){audit(l);if(selected.equals("none")){Files.writeString(out.resolve("complete.txt"),"Three pivot blocks and child bodies retained while staff-locked. No joint movement or walking qualification.\n");server.halt(false);}else Files.writeString(out.resolve("poses.csv"),"tick,phase,knee_qx,knee_qy,knee_qz,knee_qw,knee_locked,hip_pitch_qx,hip_pitch_qy,hip_pitch_qz,hip_pitch_qw,hip_pitch_locked,hip_roll_qx,hip_roll_qy,hip_roll_qz,hip_roll_qw,hip_roll_locked\n");}
   if(!selected.equals("none")&&tick==230){recordPoses(l,"before_impulse");impulse(l);}
   if(!selected.equals("none")&&tick>=240&&tick<=360&&tick%10==0)recordPoses(l,"after_impulse");
   if(!selected.equals("none")&&tick==360){Files.writeString(out.resolve("complete.txt"),"Test-only angular velocity applied; inspect orientations and locks. No motor-driven movement or walking qualification.\n");server.halt(false);}
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
