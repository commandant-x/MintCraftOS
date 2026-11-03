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
import net.minecraft.world.item.Items;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.entity.projectile.Arrow;
import net.minecraft.world.phys.AABB;
import java.nio.file.*;

/** Bench uses only vanilla blocks and items; fixture records observations. */
@Mod("mintcraft_probe")
public class SculkProjectileProbe {
 private final Path out=Path.of("mintcraft-sculk-projectile");
 private final BlockPos dispenser=new BlockPos(100,169,100), sensor=new BlockPos(105,169,104);
 private int tick,blockedPeak,clearPeak;private boolean fired1,fired2;
 public SculkProjectileProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 private void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 private void tick(ServerTickEvent.Post e){var server=e.getServer();ServerLevel l=server.overworld();tick++;
  try{
   if(tick==20){Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");Files.writeString(out.resolve("trace.csv"),"tick,case,sensor_power,arrow_count,max_arrow_x\n");for(int cx=6;cx<=7;cx++)for(int cz=6;cz<=7;cz++)l.setChunkForced(cx,cz,true);}
   if(tick==100){for(int x=97;x<=122;x++)for(int z=97;z<=108;z++){l.setBlock(new BlockPos(x,166,z),Blocks.STONE.defaultBlockState(),3);for(int y=167;y<=173;y++)l.setBlock(new BlockPos(x,y,z),Blocks.AIR.defaultBlockState(),3);}l.setBlock(dispenser,Blocks.DISPENSER.defaultBlockState().setValue(DispenserBlock.FACING,Direction.EAST),3);((DispenserBlockEntity)l.getBlockEntity(dispenser)).setItem(0,new ItemStack(Items.ARROW,8));l.setBlock(sensor,Blocks.SCULK_SENSOR.defaultBlockState(),3);for(int y=167;y<=170;y++)for(int z=101;z<=103;z++)l.setBlock(new BlockPos(102,y,z),Blocks.WHITE_WOOL.defaultBlockState(),3);for(int y=167;y<=170;y++)l.setBlock(new BlockPos(112,y,100),Blocks.STONE.defaultBlockState(),3);event("Vanilla dispenser, arrow, sculk sensor, wool acoustic barrier and stone target placed");}
   if(tick==180||tick==360){l.setBlock(dispenser.west(),Blocks.REDSTONE_BLOCK.defaultBlockState(),3);event(tick==180?"BLOCKED shot":"CLEAR shot");}
   if(tick==184||tick==364)l.setBlock(dispenser.west(),Blocks.AIR.defaultBlockState(),3);
   if(tick==300){for(int y=167;y<=170;y++)l.setBlock(new BlockPos(112,y,100),Blocks.AIR.defaultBlockState(),3);for(var arrow:l.getEntitiesOfClass(Arrow.class,new AABB(95,160,95,150,180,110)))arrow.discard();event("Removed target, retained the same wool barrier");}
   if((tick>=180&&tick<=270)||(tick>=360&&tick<=450)){String name=tick<300?"blocked":"clear";int power=l.getBlockState(sensor).getValue(SculkSensorBlock.POWER);var arrows=l.getEntitiesOfClass(Arrow.class,new AABB(95,160,95,150,180,110));double x=arrows.stream().mapToDouble(Arrow::getX).max().orElse(-1);if(tick<300){blockedPeak=Math.max(blockedPeak,power);if(!arrows.isEmpty())fired1=true;}else{clearPeak=Math.max(clearPeak,power);if(!arrows.isEmpty())fired2=true;}Files.writeString(out.resolve("trace.csv"),tick+","+name+","+power+","+arrows.size()+","+x+"\n",StandardOpenOption.APPEND);}
   if(tick==455){event("RESULT blocked_peak="+blockedPeak+" clear_peak="+clearPeak+" arrows_seen="+fired1+","+fired2);Files.writeString(out.resolve("result.txt"),"blocked_peak="+blockedPeak+" clear_peak="+clearPeak+" arrows_seen="+fired1+","+fired2+"\n");Files.writeString(out.resolve("complete.txt"),"Observational trial; inspect both traces, no lidar claim.\n");for(int cx=6;cx<=7;cx++)for(int cz=6;cz<=7;cz++)l.setChunkForced(cx,cz,false);server.halt(false);return;}
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}
 }
}
