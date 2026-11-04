package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.DispenserBlock;
import net.minecraft.world.level.block.SculkSensorBlock;
import net.minecraft.world.level.block.entity.DispenserBlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.entity.projectile.Arrow;
import net.minecraft.world.phys.AABB;
import java.nio.file.*;

/** Existing Minecraft blocks only; records data without connecting to Sputnik. */
@Mod("mintcraft_probe")
public class SculkMaterialsTunedProbe {
 private final Path out=Path.of("mintcraft-sculk-tuned");
 private final BlockPos dispenser=new BlockPos(100,169,100),sensor=new BlockPos(106,169,103);
 private final String[] cases={"stone","log","leaves","clear"};
 private int tick,peak;private boolean fired;private double finalX;
 public SculkMaterialsTunedProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 private void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 private void target(ServerLevel l,String name){BlockState state=switch(name){case "stone"->Blocks.STONE.defaultBlockState();case "log"->Blocks.OAK_LOG.defaultBlockState();case "leaves"->Blocks.OAK_LEAVES.defaultBlockState().setValue(BlockStateProperties.PERSISTENT,true);default->Blocks.AIR.defaultBlockState();};for(int y=167;y<=171;y++)for(int z=98;z<=102;z++)l.setBlock(new BlockPos(112,y,z),state,3);}
 private void tick(ServerTickEvent.Post e){var server=e.getServer();var l=server.overworld();tick++;
 try{
  if(tick==20){Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");Files.writeString(out.resolve("trace.csv"),"tick,case,rep,sensor_power,arrow_count,max_arrow_x\n");Files.writeString(out.resolve("results.csv"),"case,rep,peak,arrow_seen,last_x\n");for(int x=6;x<=7;x++)for(int z=6;z<=7;z++)l.setChunkForced(x,z,true);}
  if(tick==100){for(int x=97;x<=122;x++)for(int z=97;z<=108;z++){l.setBlock(new BlockPos(x,166,z),Blocks.STONE.defaultBlockState(),3);for(int y=167;y<=173;y++)l.setBlock(new BlockPos(x,y,z),Blocks.AIR.defaultBlockState(),3);}l.setBlock(dispenser,Blocks.DISPENSER.defaultBlockState().setValue(DispenserBlock.FACING,Direction.EAST),3);((DispenserBlockEntity)l.getBlockEntity(dispenser)).setItem(0,new ItemStack(Items.ARROW,32));l.setBlock(sensor,Blocks.SCULK_SENSOR.defaultBlockState(),3);for(int y=167;y<=171;y++)for(int z=101;z<=103;z++)l.setBlock(new BlockPos(102,y,z),Blocks.WHITE_WOOL.defaultBlockState(),3);for(int x=112;x<=122;x++)for(int z=98;z<=102;z++)for(int y=150;y<=166;y++)l.setBlock(new BlockPos(x,y,z),Blocks.AIR.defaultBlockState(),3);event("Vanilla dispenser, sculk sensor, wool barrier, open gap beyond target placed");}
  int cycle=(tick-150)/120, phase=(tick-150)%120;
  if(tick>=150&&cycle<12){String kind=cases[cycle/3];int rep=cycle%3+1;
   if(phase==0){target(l,kind);for(var a:l.getEntitiesOfClass(Arrow.class,new AABB(95,160,95,150,180,110)))a.discard();peak=0;fired=false;finalX=-1;event("Prepared "+kind+" rep="+rep);}
   if(phase==40){l.setBlock(dispenser.west(),Blocks.REDSTONE_BLOCK.defaultBlockState(),3);event("Shot "+kind+" rep="+rep);}
   if(phase==44)l.setBlock(dispenser.west(),Blocks.AIR.defaultBlockState(),3);
   if(phase>=40&&phase<=110){int power=l.getBlockState(sensor).getValue(SculkSensorBlock.POWER);var arrows=l.getEntitiesOfClass(Arrow.class,new AABB(95,160,95,150,180,110));if(!arrows.isEmpty()){fired=true;finalX=arrows.stream().mapToDouble(Arrow::getX).max().orElse(-1);}peak=Math.max(peak,power);Files.writeString(out.resolve("trace.csv"),tick+","+kind+","+rep+","+power+","+arrows.size()+","+finalX+"\n",StandardOpenOption.APPEND);}
   if(phase==111){Files.writeString(out.resolve("results.csv"),kind+","+rep+","+peak+","+fired+","+finalX+"\n",StandardOpenOption.APPEND);event("Result "+kind+" rep="+rep+" peak="+peak+" arrow="+fired+" lastX="+finalX);}
  }
  if(tick==1590){Files.writeString(out.resolve("complete.txt"),"Material observations complete; not integrated into a robot.\n");for(int x=6;x<=7;x++)for(int z=6;z<=7;z++)l.setChunkForced(x,z,false);server.halt(false);return;}
 }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
