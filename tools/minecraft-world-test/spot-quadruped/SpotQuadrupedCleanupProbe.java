package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import java.nio.file.*;
import java.util.*;
@Mod("mintcraft_probe")
public class SpotQuadrupedCleanupProbe {
 int tick;final Path out=Path.of("mintcraft-quadruped-cleanup");
 public SpotQuadrupedCleanupProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 void tick(ServerTickEvent.Post e){var l=e.getServer().overworld();tick++;
  try{
   if(tick==20){Files.createDirectories(out);for(int x=1;x<=3;x++)for(int z=1;z<=3;z++)l.setChunkForced(x,z,true);Files.writeString(out.resolve("samples.tsv"),"tick\tbodies\tpivots\tassembled\tchildren_present\tmotors\tmotor_rpm\tstaff_locked\tchassis_x\tchassis_y\tchassis_z\n");}
   if(tick==200){var c=SubLevelContainer.getContainer(l);int n=0;for(var part:new ArrayList<>(c.getAllSubLevels()))if(c.removeForceLoadTicket(part,dev.ryanhcode.sable.api.sublevel.ticket.SubLevelLoadingTicketType.COMMAND_FORCED,net.minecraft.util.Unit.INSTANCE))n++;Files.writeString(out.resolve("tickets.txt"),"removed_command_forced="+n+"\nremaining_ticket_entries="+c.getAllTickets().size()+"\n");}
   if(tick>=40&&tick<=320&&tick%20==0){var c=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);int bodies=c.getAllSubLevels().size(),pivots=0,assembled=0,present=0,motors=0,locked=0;float rpm=0;dev.ryanhcode.sable.sublevel.ServerSubLevel chassis=null;
    for(var part:c.getAllSubLevels()){if(staff.isLocked(part))locked++;for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
     if(be instanceof SwivelBearingBlockEntity b){pivots++;if(b.isAssembled())assembled++;if(b.getSubLevelID()!=null&&c.getSubLevel(b.getSubLevelID())!=null)present++;}
     if(be instanceof CreativeMotorBlockEntity m){motors++;rpm=m.getSpeed();chassis=part;}
    }}
    String pos=chassis==null?"NaN\tNaN\tNaN":chassis.logicalPose().position().x()+"\t"+chassis.logicalPose().position().y()+"\t"+chassis.logicalPose().position().z();
    Files.writeString(out.resolve("samples.tsv"),tick+"\t"+bodies+"\t"+pivots+"\t"+assembled+"\t"+present+"\t"+motors+"\t"+rpm+"\t"+locked+"\t"+pos+"\n",StandardOpenOption.APPEND);
   }
   if(tick==320){Files.writeString(out.resolve("complete.txt"),"Removed forced tickets and sampled real standing world; inspect trace and next reload.\n");e.getServer().halt(false);}
  }catch(Exception x){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+x+"\n");}catch(Exception ignored){}x.printStackTrace();e.getServer().halt(false);}
 }
}
