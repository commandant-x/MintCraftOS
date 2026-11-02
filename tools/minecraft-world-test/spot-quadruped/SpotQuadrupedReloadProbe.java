package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import java.nio.file.*;
@Mod("mintcraft_probe")
public class SpotQuadrupedReloadProbe {
 int tick;final Path out=Path.of("mintcraft-quadruped-reload");
 public SpotQuadrupedReloadProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 void tick(ServerTickEvent.Post e){var l=e.getServer().overworld();tick++;
  try{
   if(tick==20){Files.createDirectories(out);for(int x=1;x<=3;x++)for(int z=1;z<=3;z++)l.setChunkForced(x,z,true);Files.writeString(out.resolve("samples.tsv"),"tick\tbodies\tpivots\tassembled\tchildren_present\tmotors\tmotor_rpm\n");}
   if(tick>=40&&tick<=300&&tick%20==0){var c=SubLevelContainer.getContainer(l);int bodies=c.getAllSubLevels().size(),pivots=0,assembled=0,present=0,motors=0;float rpm=0;
    for(var part:c.getAllSubLevels())for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
     if(be instanceof SwivelBearingBlockEntity b){pivots++;if(b.isAssembled())assembled++;if(b.getSubLevelID()!=null&&c.getSubLevel(b.getSubLevelID())!=null)present++;}
     if(be instanceof CreativeMotorBlockEntity m){motors++;rpm=m.getSpeed();}
    }
    Files.writeString(out.resolve("samples.tsv"),tick+"\t"+bodies+"\t"+pivots+"\t"+assembled+"\t"+present+"\t"+motors+"\t"+rpm+"\n",StandardOpenOption.APPEND);
   }
   if(tick==300){Files.writeString(out.resolve("complete.txt"),"Reload survey only: presence is not a movement, contact or walking test.\n");e.getServer().halt(false);}
  }catch(Exception x){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+x+"\n");}catch(Exception ignored){}x.printStackTrace();e.getServer().halt(false);}
 }
}
