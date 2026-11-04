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
 int tick;final BlockPos base=new BlockPos(32,180,32);final Path out=Path.of("mintcraft-spot-leg");
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
  set(l,1,-1,1,plank);set(l,1,-2,1,plank);set(l,1,-3,1,bearing.setValue(BlockStateProperties.FACING,Direction.EAST));
  set(l,2,-3,1,plank);set(l,2,-4,1,plank);set(l,2,-5,1,plank);
  glue(l,p(0,-1,1),p(0,0,1));glue(l,p(1,-3,1),p(1,-1,1));glue(l,p(2,-5,1),p(2,-3,1));
  event("Placed one creative motor, three swivel bearings and three short segments; motor speed 0");
 }
 void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 void assemble(ServerLevel l,BlockPos pos,String name)throws Exception{
  var be=l.getBlockEntity(pos);if(!(be instanceof SwivelBearingBlockEntity bearing))throw new IllegalStateException(name+" bearing missing at "+pos+": "+be);
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
  report.append("pivot_count=").append(count).append(" retained_children=").append(parts).append(" creative_motor_count=1 motor_rpm=0\n");Files.writeString(out.resolve("audit.txt"),report);event("AUDIT pivots="+count+" children="+parts);
  if(count!=3||parts!=3)throw new IllegalStateException("Three-joint assembly not retained");
  Files.writeString(out.resolve("complete.txt"),"Three physical pivot blocks/child bodies retained while staff-locked. No powered joint movement or walking qualification.\n");
 }
 void tick(ServerTickEvent.Post e){MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);
   if(tick==80)assemble(l,p(1,-3,1),"knee");
   if(tick==120)assemble(l,p(0,-1,1),"hip_pitch");
   if(tick==160)assemble(l,p(0,0,0),"hip_roll");
   if(tick==220){audit(l);server.halt(false);}
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
