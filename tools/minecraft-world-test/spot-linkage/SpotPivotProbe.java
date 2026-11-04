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
import com.enxv.aerouniversaljoint.content.HydraulicConnectionHeadBlockEntity;
import com.enxv.aerouniversaljoint.content.HydraulicRegulatorBlockEntity;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import java.nio.file.*;
import java.util.*;

/** Real unloaded single-link test, not a complete leg or gait. */
@Mod("mintcraft_probe")
public class SpotPivotProbe {
 final boolean hinged=Boolean.getBoolean("mintcraft.spot.hinged"); int tick; final BlockPos origin=new BlockPos(32,170,32); final Path out=Path.of("mintcraft-spot-pivot");
 ServerSubLevel body; HydraulicConnectionHeadBlockEntity anchor,moving; HydraulicRegulatorBlockEntity regulator;
 public SpotPivotProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockState block(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 BlockPos pos(int x,int y,int z){return origin.offset(x,y,z);}
 void setup(ServerLevel l)throws Exception{
  l.setChunkForced(origin.getX() >> 4, origin.getZ() >> 4, true);
  Files.createDirectories(out);Files.writeString(out.resolve("trace.csv"),"tick,phase,linked,source_rpm,regulator_rpm,target_tenths,signal,peer_loaded,anchor_current,regulator_current,overstressed,target_at_zero,target_at_fifteen,body_x,body_y,body_z,locked,hinge_present,hinge_qx,hinge_qy,hinge_qz,hinge_qw,body_qx,body_qy,body_qz,body_qw,pivot_powered,pivot_assembled,pivot_target\n");
  l.setBlock(pos(0,0,0),block("aeronautics_utility_objects:hydraulic_connection_head").setValue(BlockStateProperties.FACING,Direction.EAST),3);
  l.setBlock(pos(-1,0,0),block("aeronautics_utility_objects:hydraulic_regulator").setValue(BlockStateProperties.FACING,Direction.EAST),3);
  l.setBlock(pos(-1,0,1),block("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.NORTH),3);
  ((CreativeMotorBlockEntity)l.getBlockEntity(pos(-1,0,1))).generatedSpeed.setValue(64);
  l.setBlock(pos(4,0,1),block("simulated:swivel_bearing").setValue(BlockStateProperties.FACING,Direction.NORTH),3);
  l.setBlock(pos(4,0,0),block("minecraft:oak_planks"),3);
  l.setBlock(pos(3,0,0),block("minecraft:oak_planks"),3);
  l.setBlock(pos(3,-1,0),block("aeronautics_utility_objects:hydraulic_hinge_head").setValue(BlockStateProperties.FACING,Direction.WEST).setValue(com.enxv.aerouniversaljoint.content.HydraulicHingeHeadBlock.HINGE_AXIS,Direction.Axis.Z),3);
  l.addFreshEntity(new com.simibubi.create.content.contraptions.glue.SuperGlueEntity(l,com.simibubi.create.content.contraptions.glue.SuperGlueEntity.span(pos(3,-1,0),pos(4,0,0))));
  var bearing=(dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity)l.getBlockEntity(pos(4,0,1));
  if(Boolean.getBoolean("mintcraft.spot.pivotUnlocked")){
   var f=bearing.getClass().getDeclaredField("lockedDefaultOption");f.setAccessible(true);
   var setting=(com.simibubi.create.foundation.blockEntity.behaviour.scrollValue.ScrollOptionBehaviour<?>)f.get(bearing);
   if(setting==null)throw new IllegalStateException("Pivot lock setting not initialized");
   setting.setValue(3); // UNLOCKED_ALWAYS, equivalent to the normal in-game setting.
  }
  bearing.assemble();
  if(!bearing.isAssembled()||bearing.getSubLevelID()==null)throw new IllegalStateException("Pivot assembly failed: "+bearing.getLastAssemblyException());
  body=(ServerSubLevel)dev.ryanhcode.sable.api.sublevel.SubLevelContainer.getContainer(l).getSubLevel(bearing.getSubLevelID());
  if(body==null)throw new IllegalStateException("Pivot body not found");
  dev.ryanhcode.sable.api.sublevel.SubLevelContainer.getContainer(l).addForceLoadTicket(body,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE);
  PhysicsStaffServerHandler.get(l).toggleLock(body.getUniqueId());
  anchor=(HydraulicConnectionHeadBlockEntity)l.getBlockEntity(pos(0,0,0));regulator=(HydraulicRegulatorBlockEntity)l.getBlockEntity(pos(-1,0,0));
  for(var h:body.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values())if(be instanceof HydraulicConnectionHeadBlockEntity a)moving=a;
  if(anchor==null||moving==null||regulator==null)throw new IllegalStateException("Missing actuator components");
 }
 void link()throws Exception{
  var result=anchor.createMutualLink(moving,false);
  Files.writeString(out.resolve("link-result.txt"),result.toString()+"\n");
  if(!anchor.hasLink()||!moving.hasLink())throw new IllegalStateException("Link refused: "+result);
  anchor.setRedstoneLengthRangeAndMirror(30,50);anchor.setReturnForce(Integer.getInteger("mintcraft.spot.force",15));anchor.setStretchResistance(Integer.getInteger("mintcraft.spot.damping",10));
 }
 void record(ServerLevel l,String phase)throws Exception{
  var v=body.logicalPose().position();float source=((CreativeMotorBlockEntity)l.getBlockEntity(pos(-1,0,1))).getSpeed();
  var h=moving.getHingeSubLevelId()==null?null:dev.ryanhcode.sable.api.sublevel.SubLevelContainer.getContainer(l).getSubLevel(moving.getHingeSubLevelId());
  var q=h==null?new org.joml.Quaterniond():h.logicalPose().orientation();
  var bq=body.logicalPose().orientation();
  var pivot=(dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity)l.getBlockEntity(pos(4,0,1));
  Files.writeString(out.resolve("trace.csv"),tick+","+phase+","+anchor.hasLink()+","+source+","+regulator.getSpeed()+","+anchor.getExpectedLengthTenths()+","+l.getBestNeighborSignal(pos(-1,0,0))+","+(anchor.getLoadedLinkedConnectionHead()!=null)+","+(l.getBlockEntity(pos(0,0,0))==anchor)+","+(l.getBlockEntity(pos(-1,0,0))==regulator)+","+regulator.isOverStressed()+","+anchor.getExpectedLengthTenthsForRedstoneSignal(0)+","+anchor.getExpectedLengthTenthsForRedstoneSignal(15)+","+v.x()+","+v.y()+","+v.z()+","+PhysicsStaffServerHandler.get(l).isLocked(body)+","+(h!=null)+","+q.x()+","+q.y()+","+q.z()+","+q.w()+","+bq.x()+","+bq.y()+","+bq.z()+","+bq.w()+","+l.getBlockState(pos(4,0,1)).getValue(BlockStateProperties.POWERED)+","+pivot.isAssembled()+","+pivot.getTargetAngleDegrees()+"\n",StandardOpenOption.APPEND);
 }
 void tick(ServerTickEvent.Post e){MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);if(tick==100)link();
   if(tick==180)record(l,"off_locked");
   if(tick==200)l.setBlock(pos(-1,1,0),block("minecraft:redstone_block"),3);
   if(tick==300)record(l,"on_locked");
   if(tick==305)l.removeBlock(pos(-1,1,0),false);
   if(tick==315)record(l,"off_again_locked");
   if(tick==320)PhysicsStaffServerHandler.get(l).removeLock(body);
   if(tick==325)l.setBlock(pos(-1,1,0),block("minecraft:redstone_block"),3);
   if(tick>=330&&tick<=500&&tick%10==0)record(l,"released_on");
   if(tick==510)l.removeBlock(pos(-1,1,0),false);
   if(tick>=520&&tick<=700&&tick%10==0)record(l,"released_off");
   if(tick==710)((CreativeMotorBlockEntity)l.getBlockEntity(pos(-1,0,1))).generatedSpeed.setValue(0);
   if(tick==740)l.setBlock(pos(-1,1,0),block("minecraft:redstone_block"),3);
   if(tick>=750&&tick<=850&&tick%10==0)record(l,"motor_stopped_on");
   if(tick==850){Files.writeString(out.resolve("complete.txt"),"Observation finished; inspect trace; not proof of a controlled leg.\n");server.halt(false);}
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
