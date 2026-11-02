package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity;
import java.nio.file.*;
import java.util.*;
@Mod("mintcraft_probe")
public class SpotReloadProbe {
 int tick; final BlockPos root=new BlockPos(32,180,32); final Path out=Path.of("mintcraft-reload-audit");
 public SpotReloadProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 void tick(ServerTickEvent.Post e){
  tick++;var l=e.getServer().overworld();
  try{
   if(tick==20){Files.createDirectories(out);l.setChunkForced(root.getX()>>4,root.getZ()>>4,true);Files.writeString(out.resolve("samples.tsv"),"tick\tsubleves\tbearings\tassembled\tchildren_present\tmissing_ids\tdetail\n");}
   if(tick>=40&&tick<=400&&tick%20==0){
    var c=SubLevelContainer.getContainer(l);var all=c.getAllSubLevels();int bearings=0,assembled=0,present=0;List<String> missing=new ArrayList<>(),details=new ArrayList<>();
    List<SwivelBearingBlockEntity> list=new ArrayList<>();if(l.getBlockEntity(root) instanceof SwivelBearingBlockEntity b)list.add(b);
    for(var craft:all)for(var holder:craft.getPlot().getLoadedChunks())for(var be:holder.getChunk().getBlockEntities().values())if(be instanceof SwivelBearingBlockEntity b)list.add(b);
    for(var b:list){bearings++;if(b.isAssembled())assembled++;UUID id=b.getSubLevelID();boolean found=id!=null&&c.getSubLevel(id)!=null;if(found)present++;else missing.add(String.valueOf(id));details.add(b.getBlockState().getValue(BlockStateProperties.FACING).getAxis()+":"+b.isAssembled()+":"+id+":"+found);}
    Files.writeString(out.resolve("samples.tsv"),tick+"\t"+all.size()+"\t"+bearings+"\t"+assembled+"\t"+present+"\t"+String.join(",",missing)+"\t"+String.join(";",details)+"\n",StandardOpenOption.APPEND);
   }
   if(tick==400){Files.writeString(out.resolve("complete.txt"),"Reload observations complete; bearing flags and Sable presence only, not a motion or constraint test.\n");e.getServer().halt(false);}
  }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),ex.toString());}catch(Exception ignored){}ex.printStackTrace();e.getServer().halt(false);}
 }
}
