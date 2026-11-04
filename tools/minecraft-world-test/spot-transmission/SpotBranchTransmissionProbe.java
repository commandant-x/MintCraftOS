package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import com.simibubi.create.content.kinetics.base.KineticBlockEntity;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import java.nio.file.*;

/** Test-only instrumentation for three independent vanilla/Create branch controls. */
@Mod("mintcraft_probe")
public class SpotBranchTransmissionProbe {
 final Path out=Path.of("mintcraft-spot-branch-transmission");final BlockPos base=new BlockPos(96,180,96);final int[] branches={2,5,8};int tick;double beforeA,beforeB;
 public SpotBranchTransmissionProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 BlockPos p(int x,int y,int z){return base.offset(x,y,z);} BlockState b(String id){return BuiltInRegistries.BLOCK.get(ResourceLocation.parse(id)).defaultBlockState();}
 BlockState axis(String id,Direction.Axis a){return b(id).setValue(BlockStateProperties.AXIS,a);}
 void set(ServerLevel l,BlockPos p,BlockState s){l.setBlock(p,s,3);}
 void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 double rpm(ServerLevel l,BlockPos p){var be=l.getBlockEntity(p);if(!(be instanceof KineticBlockEntity k))throw new IllegalStateException("missing kinetic entity at "+p+": "+be);return k.getSpeed();}
 BlockPos clutchPower(int x){return p(x+2,4,1);} BlockPos reversalPower(int x){return p(x+1,5,2);} BlockPos output(int x){return p(x+1,6,1);}
 void sample(ServerLevel l)throws Exception{StringBuilder s=new StringBuilder().append(tick).append(',').append(rpm(l,p(0,0,0)));for(int x:branches)s.append(',').append(rpm(l,p(x,2,0))).append(',').append(rpm(l,p(x+1,2,1))).append(',').append(rpm(l,output(x)));Files.writeString(out.resolve("rpm.csv"),s.append('\n'),StandardOpenOption.APPEND);}
 void eq(double x,double expected,String name){if(Math.abs(x-expected)>.01)throw new IllegalStateException(name+" expected "+expected+" got "+x);}
 void tick(ServerTickEvent.Post e){var server=e.getServer();var l=server.overworld();tick++;
 try{
  if(tick==20){Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");Files.writeString(out.resolve("rpm.csv"),"tick,motor,a_input,a_reduced,a_output,b_input,b_reduced,b_output,c_input,c_reduced,c_output\n");for(int x=5;x<=7;x++)for(int z=5;z<=7;z++)l.setChunkForced(x,z,true);}
  if(tick==50){for(int x=-2;x<=12;x++)for(int y=-1;y<=8;y++)for(int z=-2;z<=4;z++)set(l,p(x,y,z),Blocks.AIR.defaultBlockState());
   set(l,p(0,0,0),b("create:creative_motor").setValue(BlockStateProperties.FACING,Direction.EAST));((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,0))).generatedSpeed.setValue(0);
   for(int x=1;x<=9;x++)set(l,p(x,0,0),x==2||x==5||x==8?axis("create:gearbox",Direction.Axis.Z):axis("create:shaft",Direction.Axis.X));
   for(int x:branches){set(l,p(x,1,0),axis("create:shaft",Direction.Axis.Y));set(l,p(x,2,0),axis("create:cogwheel",Direction.Axis.Y));set(l,p(x+1,2,1),axis("create:large_cogwheel",Direction.Axis.Y));set(l,p(x+1,3,1),axis("create:shaft",Direction.Axis.Y));set(l,p(x+1,4,1),axis("create:clutch",Direction.Axis.Y));set(l,p(x+1,5,1),axis("create:gearshift",Direction.Axis.Y));set(l,output(x),axis("create:shaft",Direction.Axis.Y));set(l,clutchPower(x),Blocks.REDSTONE_BLOCK.defaultBlockState());}
   event("Constructed one creative motor and three separately clutched and reversible small-to-large gear branches");}
  if(tick==110){((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,0))).generatedSpeed.setValue(128);event("Motor commanded to 128 RPM; all clutches powered closed");}
  if(tick>=120&&tick<=360)sample(l);
  if(tick==150){eq(Math.abs(rpm(l,p(0,0,0))),128,"motor");for(int x:branches){eq(Math.abs(rpm(l,p(x,2,0))),128,"small cog "+x);eq(Math.abs(rpm(l,p(x+1,2,1))),64,"large cog "+x);eq(rpm(l,output(x)),0,"closed output "+x);}event("All three branches have 128 RPM input, 64 RPM reduced, 0 output when closed");}
  if(tick==160){set(l,clutchPower(branches[0]),Blocks.AIR.defaultBlockState());event("Opened branch A only");}
  if(tick==190){eq(Math.abs(rpm(l,output(2))),64,"A open");eq(rpm(l,output(5)),0,"B closed");eq(rpm(l,output(8)),0,"C closed");event("A runs at 64 RPM while B and C remain stopped");}
  if(tick==200){set(l,clutchPower(branches[1]),Blocks.AIR.defaultBlockState());event("Opened branch B as well");}
  if(tick==230){beforeA=rpm(l,output(2));beforeB=rpm(l,output(5));eq(Math.abs(beforeA),64,"A");eq(Math.abs(beforeB),64,"B");eq(rpm(l,output(8)),0,"C");set(l,reversalPower(2),Blocks.REDSTONE_BLOCK.defaultBlockState());event("Reversed branch A alone while A and B are running");}
  if(tick==260){eq(rpm(l,output(2)),-beforeA,"A reversed");eq(rpm(l,output(5)),beforeB,"B unchanged");eq(rpm(l,output(8)),0,"C closed");event("A reversed independently; B unchanged; C stopped");set(l,clutchPower(2),Blocks.REDSTONE_BLOCK.defaultBlockState());set(l,clutchPower(8),Blocks.AIR.defaultBlockState());}
  if(tick==300){eq(rpm(l,output(2)),0,"A closed");eq(rpm(l,output(5)),beforeB,"B unchanged");eq(Math.abs(rpm(l,output(8))),64,"C open");event("A closed; B and C running at reduced speed");((CreativeMotorBlockEntity)l.getBlockEntity(p(0,0,0))).generatedSpeed.setValue(0);}
  if(tick==330){for(int x:branches)eq(rpm(l,output(x)),0,"output stopped");Files.writeString(out.resolve("complete.txt"),"128 RPM motor, three 2:1 branches, selective clutches and independent reversal observed on Create bench. No swivel, load or gait claim.\n");for(int x=5;x<=7;x++)for(int z=5;z<=7;z++)l.setChunkForced(x,z,false);server.halt(false);return;}
 }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
