package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.simulated_team.simulated.content.blocks.swivel_bearing.SwivelBearingBlockEntity;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import com.simibubi.create.content.kinetics.motor.CreativeMotorBlockEntity;
import com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity;
import dev.devce.rocketnautics.content.blocks.SputnikBlockEntity;
import dev.devce.websnodelib.api.elements.WCheckbox;
import java.nio.file.*;
@Mod("mintcraft_probe")
public class SpotQuadrupedSputnikReloadProbe {
 int tick;final Path out=Path.of("mintcraft-quadruped-sputnik-reload");
 public SpotQuadrupedSputnikReloadProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 void tick(ServerTickEvent.Post e){var l=e.getServer().overworld();tick++;
  try{
   if(tick==20){Files.createDirectories(out);for(int x=1;x<=3;x++)for(int z=1;z<=3;z++)l.setChunkForced(x,z,true);Files.writeString(out.resolve("samples.tsv"),"tick\tbodies\tpivots\tassembled\tchildren_present\tmotors\tmotor_rpm\tstaff_locked\treceivers\treceivers_15\treceivers_0\tsputnik\tnodes\tconnections\tcheckboxes\tchecked\tcontroller_bridge\n");}
   if(tick>=60&&tick<=300&&tick%20==0){var c=SubLevelContainer.getContainer(l);var staff=PhysicsStaffServerHandler.get(l);int bodies=c.getAllSubLevels().size(),pivots=0,assembled=0,present=0,motors=0,locked=0,rx=0,rx15=0,rx0=0,spcount=0,nodes=0,edges=0,boxes=0,checked=0,bridge=0;float rpm=0;
    for(var part:c.getAllSubLevels()){if(staff.isLocked(part))locked++;for(var h:part.getPlot().getLoadedChunks())for(var be:h.getChunk().getBlockEntities().values()){
     if(be instanceof SwivelBearingBlockEntity b){pivots++;if(b.isAssembled())assembled++;if(b.getSubLevelID()!=null&&c.getSubLevel(b.getSubLevelID())!=null)present++;}
     if(be instanceof CreativeMotorBlockEntity m){motors++;rpm=m.getSpeed();}
     if(be instanceof RedstoneLinkBlockEntity link){rx++;if(link.getReceivedSignal()==15)rx15++;if(link.getReceivedSignal()==0)rx0++;}
     if(be instanceof SputnikBlockEntity sp){spcount++;nodes=sp.graph.getNodes().size();edges=sp.graph.getConnections().size();for(var node:sp.graph.getNodes()){
      if(node.getCustomData().getString("code").contains("transmitWirelessRedstone")&&node.getCustomData().getString("code").contains("MintSpotQuadrupedGait"))bridge++;
      for(var element:node.getElements())if(element instanceof WCheckbox box){boxes++;if(box.isChecked())checked++;}
     }}
    }}
    Files.writeString(out.resolve("samples.tsv"),tick+"\t"+bodies+"\t"+pivots+"\t"+assembled+"\t"+present+"\t"+motors+"\t"+rpm+"\t"+locked+"\t"+rx+"\t"+rx15+"\t"+rx0+"\t"+spcount+"\t"+nodes+"\t"+edges+"\t"+boxes+"\t"+checked+"\t"+bridge+"\n",StandardOpenOption.APPEND);
   }
   if(tick==300){Files.writeString(out.resolve("complete.txt"),"Reload inventory only; inspect node, receiver and lock measurements.\n");e.getServer().halt(false);}
  }catch(Exception x){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+x+"\n");}catch(Exception ignored){}x.printStackTrace();e.getServer().halt(false);}
 }
}
