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
public class SpotLinkageProbe {
 int tick; final BlockPos origin=new BlockPos(32,170,32); final Path out=Path.of("mintcraft-spot-linkage");
 ServerSubLevel body; HydraulicConnectionHeadBlockEntity anchor,moving; HydraulicRegulatorBlockEntity regulator;
 public SpotLinkageProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockState block(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 BlockPos pos(int x,int y,int z){return origin.offset(x,y,z);}
 void setup(ServerLevel l)throws Exception{
  l.setChunkForced(origin.getX() >> 4, origin.getZ() >> 4, true);
  Files.createDirectories(out);Files.writeString(out.resolve("trace.csv"),"tick,phase,linked,source_rpm,regulator_rpm,target_tenths,signal,peer_loaded,anchor_current,regulator_current,overstressed,target_at_zero,target_at_fifteen,body_x,body_y,body_z,locked\n");
  l.setBlock(pos(0,0,0),block("aeronautics_utility_objects:hydraulic_connection_head").setValue(BlockStateProperties.FACING,Direction.EAST),3);
  l.setBlock(pos(-1,0,0),block("aeronautics_utility_objects:hydraulic_regulator").setValue(BlockStateProperties.FACING,Direction.EAST),3);
  l.setBlock(pos(-1,0,1),block("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.NORTH),3);
  ((CreativeMotorBlockEntity)l.getBlockEntity(pos(-1,0,1))).generatedSpeed.setValue(64);
  l.setBlock(pos(4,0,0),block("aeronautics_utility_objects:hydraulic_connection_head").setValue(BlockStateProperties.FACING,Direction.WEST),3);
  l.setBlock(pos(5,0,0),block("minecraft:oak_planks"),3);
  var locations=Set.of(pos(4,0,0),pos(5,0,0));
  body=dev.ryanhcode.sable.api.SubLevelAssemblyHelper.assembleBlocks(l,pos(4,0,0),locations,dev.ryanhcode.sable.companion.math.BoundingBox3i.from(locations));
  if(body==null)throw new IllegalStateException("Sublevel assembly failed");
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
  anchor.setRedstoneLengthRangeAndMirror(30,50);anchor.setReturnForce(15);anchor.setStretchResistance(10);
 }
 void record(ServerLevel l,String phase)throws Exception{
  var v=body.logicalPose().position();float source=((CreativeMotorBlockEntity)l.getBlockEntity(pos(-1,0,1))).getSpeed();
  Files.writeString(out.resolve("trace.csv"),tick+","+phase+","+anchor.hasLink()+","+source+","+regulator.getSpeed()+","+anchor.getExpectedLengthTenths()+","+l.getBestNeighborSignal(pos(-1,0,0))+","+(anchor.getLoadedLinkedConnectionHead()!=null)+","+(l.getBlockEntity(pos(0,0,0))==anchor)+","+(l.getBlockEntity(pos(-1,0,0))==regulator)+","+regulator.isOverStressed()+","+anchor.getExpectedLengthTenthsForRedstoneSignal(0)+","+anchor.getExpectedLengthTenthsForRedstoneSignal(15)+","+v.x()+","+v.y()+","+v.z()+","+PhysicsStaffServerHandler.get(l).isLocked(body)+"\n",StandardOpenOption.APPEND);
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
