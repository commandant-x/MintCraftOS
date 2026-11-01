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
import net.minecraft.world.level.block.LeverBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.AttachFace;
import com.simibubi.create.content.kinetics.base.KineticBlockEntity;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import java.nio.file.*;
import java.util.*;

/** Isolated static transmission bench: one creative source, four switched branches. */
@Mod("mintcraft_probe")
public class SpotTransmissionProbe {
 private int tick; private final BlockPos base=new BlockPos(32,100,32);
 private final int[] x={-6,-2,2,6};
 private final Path output=Path.of("mintcraft-spot-transmission");
 public SpotTransmissionProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 private BlockState block(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 private void set(ServerLevel l,int a,int b,int c,BlockState s){l.setBlock(base.offset(a,b,c),s,3);}
 private void lever(ServerLevel l,int branch,boolean value){BlockPos p=base.offset(x[branch],1,2);BlockState s=l.getBlockState(p);if(!(s.getBlock() instanceof LeverBlock))throw new IllegalStateException("lever absent");l.setBlock(p,s.setValue(BlockStateProperties.POWERED,value),3);}
 private float speed(ServerLevel l,int a,int b,int c){var be=l.getBlockEntity(base.offset(a,b,c));if(!(be instanceof KineticBlockEntity k))throw new IllegalStateException("missing kinetic block "+a+","+b+","+c);return k.getSpeed();}
 private void setup(ServerLevel l)throws Exception{
  Files.createDirectories(output);Files.writeString(output.resolve("measurements.csv"),"tick,phase,source_rpm,branch1_rpm,branch2_rpm,branch3_rpm,branch4_rpm\n");
  for(int a=-6;a<=6;a++){
   boolean box=false;for(int v:x)if(a==v)box=true;
   set(l,a,0,0,box?block("create:gearbox").setValue(BlockStateProperties.AXIS,Direction.Axis.Y):block("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.X));
  }
  set(l,-7,0,0,block("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.EAST));
  ((CreativeMotorBlockEntity)l.getBlockEntity(base.offset(-7,0,0))).generatedSpeed.setValue(64);
  for(int a:x){
   set(l,a,0,1,block("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
   set(l,a,0,2,block("create:clutch").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
   set(l,a,0,3,block("create:shaft").setValue(BlockStateProperties.AXIS,Direction.Axis.Z));
   set(l,a,1,2,block("minecraft:lever").setValue(BlockStateProperties.ATTACH_FACE,AttachFace.FLOOR).setValue(BlockStateProperties.POWERED,false));
  }
  Files.writeString(output.resolve("events.txt"),"One creative motor; four gearboxes and four clutch branches; static non-walking bench.\n");
 }
 private void record(ServerLevel l,String phase)throws Exception{
  var s=new StringBuilder().append(tick).append(',').append(phase).append(',').append(speed(l,-7,0,0));for(int a:x)s.append(',').append(speed(l,a,0,3));s.append('\n');Files.writeString(output.resolve("measurements.csv"),s,StandardOpenOption.APPEND);
 }
 private void tick(ServerTickEvent.Post e){
  MinecraftServer server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==40)setup(l);
   if(tick==200)record(l,"all_connected");
   for(int i=0;i<4;i++){
    int start=220+i*100;
    if(tick==start)lever(l,i,true);
    if(tick==start+60)record(l,"branch_"+(i+1)+"_disconnected");
    if(tick==start+80)lever(l,i,false);
   }
   if(tick==700){record(l,"all_reconnected");Files.writeString(output.resolve("complete.txt"),"Completed static observations. Inspect measurements; completion is not a mechanical pass.\n");server.halt(false);}
  }catch(Exception ex){try{Files.createDirectories(output);Files.writeString(output.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
