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
import com.simibubi.create.content.kinetics.base.KineticBlockEntity;
import com.enxv.aerouniversaljoint.content.UniversalJointBlockEntity;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import dev.ryanhcode.sable.api.physics.handle.RigidBodyHandle;
import org.joml.Vector3d;
import org.joml.Quaterniond;
import java.nio.file.*;
import java.util.*;

/** Actual universal-joint RPM between two isolated Sable structures; no gait. */
@Mod("mintcraft_probe")
public class UniversalTransmissionProbe {
 final boolean brass=Boolean.getBoolean("mintcraft.spot.brass"); int tick;
 final BlockPos base=new BlockPos(32,170,32);final Path out=Path.of("mintcraft-spot-universal");
 ServerSubLevel first,second; UniversalJointBlockEntity sourceJoint,targetJoint;CreativeMotorBlockEntity motor;KineticBlockEntity outputShaft; Vector3d start;Quaterniond orientation;
 public UniversalTransmissionProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockPos pos(int x){return base.offset(x,0,0);} BlockState b(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 ServerSubLevel assemble(ServerLevel l,Set<BlockPos> positions,BlockPos center){
  var body=dev.ryanhcode.sable.api.SubLevelAssemblyHelper.assembleBlocks(l,center,positions,dev.ryanhcode.sable.companion.math.BoundingBox3i.from(positions));
  if(body==null)throw new IllegalStateException("Assembly failed");SubLevelContainer.getContainer(l).addForceLoadTicket(body,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE);PhysicsStaffServerHandler.get(l).toggleLock(body.getUniqueId());return body;
 }
 void setup(ServerLevel l)throws Exception{
  l.setChunkForced(base.getX()>>4,base.getZ()>>4,true);Files.createDirectories(out);Files.writeString(out.resolve("trace.csv"),"tick,phase,brass,linked,first_locked,second_locked,motor_rpm,source_joint_rpm,target_joint_rpm,shaft_rpm,second_x,second_y,second_z\n");
  String block=brass?"aeronautics_utility_objects:brass_universal_joint":"aeronautics_utility_objects:universal_joint";
  l.setBlock(pos(0),b("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.EAST),3);
  l.setBlock(pos(1),b(block).setValue(BlockStateProperties.FACING,Direction.EAST),3);
  l.setBlock(pos(4),b(block).setValue(BlockStateProperties.FACING,Direction.WEST),3);
  l.setBlock(pos(5),b("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.X),3);
  ((CreativeMotorBlockEntity)l.getBlockEntity(pos(0))).generatedSpeed.setValue(64);
  first=assemble(l,Set.of(pos(0),pos(1)),pos(0));second=assemble(l,Set.of(pos(4),pos(5)),pos(4));
  for(var h:first.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
   if(be instanceof UniversalJointBlockEntity j)sourceJoint=j;
   if(be instanceof CreativeMotorBlockEntity m)motor=m;
  }
  for(var h:second.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
   if(be instanceof UniversalJointBlockEntity j)targetJoint=j;
   else if(be instanceof KineticBlockEntity k)outputShaft=k;
  }
  if(motor==null||sourceJoint==null||targetJoint==null||outputShaft==null)throw new IllegalStateException("Missing motor, joint or shaft");
  motor.generatedSpeed.setValue(64);start=new Vector3d(second.logicalPose().position());orientation=new Quaterniond(second.logicalPose().orientation());
 }
 void link()throws Exception{
  var result=sourceJoint.createMutualLink(targetJoint,brass);Files.writeString(out.resolve("link-result.txt"),result.toString()+"\n");
  if(!sourceJoint.hasLink()||!targetJoint.hasLink())throw new IllegalStateException("Link rejected: "+result);
 }
 void move(ServerLevel l,double delta)throws Exception{
  var staff=PhysicsStaffServerHandler.get(l);if(staff.isLocked(second))staff.removeLock(second);
  var handle=RigidBodyHandle.of(second);handle.addLinearAndAngularVelocity(new Vector3d(handle.getLinearVelocity()).negate(),new Vector3d(handle.getAngularVelocity()).negate());handle.teleport(new Vector3d(start).add(0,delta,0),orientation);staff.toggleLock(second.getUniqueId());
 }
 void sample(ServerLevel l,String phase)throws Exception{
  var p=second.logicalPose().position();var locks=PhysicsStaffServerHandler.get(l);
  Files.writeString(out.resolve("trace.csv"),tick+","+phase+","+brass+","+(sourceJoint.hasLink()&&targetJoint.hasLink())+","+locks.isLocked(first)+","+locks.isLocked(second)+","+motor.getSpeed()+","+sourceJoint.getSpeed()+","+targetJoint.getSpeed()+","+outputShaft.getSpeed()+","+p.x()+","+p.y()+","+p.z()+"\n",StandardOpenOption.APPEND);
 }
 void tick(ServerTickEvent.Post e){MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);if(tick==120)link();
   if(tick==220)sample(l,"baseline");
   if(tick==240)move(l,.5);if(tick==340)sample(l,"offset_0_5");
   if(tick==360)move(l,1);if(tick==460)sample(l,"offset_1_0");
   if(tick==480)motor.generatedSpeed.setValue(0);if(tick==580)sample(l,"motor_off");
   if(tick==600)motor.generatedSpeed.setValue(64);if(tick==700){sample(l,"motor_on");Files.writeString(out.resolve("complete.txt"),"Observation complete; independently inspect speeds and link state. Both bodies clamped; not a walking test.\n");server.halt(false);}
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
