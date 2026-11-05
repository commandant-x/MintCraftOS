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
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import java.nio.file.*;

/** Isolated observations of the existing Simulated optical sensor and native Sputnik wireless. */
@Mod("mintcraft_probe")
public class NativeOpticalSensorProbe {
 int tick; final Path out=Path.of("mintcraft-native-optical"); final BlockPos sensor=new BlockPos(100,170,100); dev.devce.websnodelib.api.WNode node;
 final String[] cases={"empty","stone4","stone8","stone12","leaves8","glass8","empty_again"};
 public NativeOpticalSensorProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 void event(String s)throws Exception{Files.writeString(out.resolve("events.tsv"),tick+"\t"+s+"\n",StandardOpenOption.APPEND);}
 void tick(ServerTickEvent.Post e){var server=e.getServer();var l=server.overworld();tick++;
 try{
  if(tick==20){Files.createDirectories(out);Files.writeString(out.resolve("events.tsv"),"tick\tevent\n");Files.writeString(out.resolve("results.csv"),"tick,case,hit,block,distance,range,powered,redstone,sputnik\n");for(int x=5;x<=8;x++)for(int z=5;z<=7;z++)l.setChunkForced(x,z,true);}
  if(tick==100){for(int x=98;x<=117;x++)for(int y=168;y<=172;y++)for(int z=98;z<=103;z++)l.setBlock(new BlockPos(x,y,z),Blocks.AIR.defaultBlockState(),3);
   var block=BuiltInRegistries.BLOCK.get(ResourceLocation.parse("simulated:optical_sensor"));l.setBlock(sensor,block.defaultBlockState().setValue(BlockStateProperties.HORIZONTAL_FACING,Direction.EAST).setValue(com.simibubi.create.content.redstone.DirectedDirectionalBlock.TARGET,net.minecraft.world.level.block.state.properties.AttachFace.WALL),3);
   var linkPos=sensor.above();l.setBlock(linkPos,BuiltInRegistries.BLOCK.get(ResourceLocation.parse("create:redstone_link")).defaultBlockState().setValue(BlockStateProperties.FACING,Direction.UP).setValue(com.simibubi.create.content.redstone.link.RedstoneLinkBlock.RECEIVER,false),3);var link=l.getBlockEntity(linkPos);if(!(link instanceof com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity))throw new IllegalStateException("link absent");var tag=link.saveWithFullMetadata(l.registryAccess());tag.putBoolean("Transmitter",true);tag.put("FrequencyFirst",new ItemStack(Items.WHITE_WOOL).save(l.registryAccess()));tag.put("FrequencyLast",new ItemStack(Items.DIAMOND_BLOCK).save(l.registryAccess()));link.loadWithComponents(tag,l.registryAccess());
   var spPos=new BlockPos(100,170,105);l.setBlock(spPos,BuiltInRegistries.BLOCK.get(ResourceLocation.parse("rocketnautics:sputnik")).defaultBlockState(),3);var be=l.getBlockEntity(spPos);if(!(be instanceof dev.devce.rocketnautics.content.blocks.SputnikBlockEntity sp))throw new IllegalStateException("Sputnik absent");node=new dev.devce.websnodelib.api.WNode(ResourceLocation.parse("rocketnautics:lua_script"),"Optical wireless",20,20);dev.devce.rocketnautics.registry.RocketNodes.setupLuaEvaluatorPublic(node);node.getCustomData().putString("code","local ok,v=pcall(receiveWirelessRedstone,'minecraft:white_wool','minecraft:diamond_block')\noutput('Echo',ok and type(v)=='number' and v or -1)");sp.graph.addNode(node);event("Optical sensor, Create transmitter and Sputnik installed in isolated world");}
  int cycle=(tick-150)/80,phase=(tick-150)%80;
  if(tick>=150&&cycle<cases.length){String c=cases[cycle];if(phase==0){for(int x=101;x<=115;x++)l.setBlock(new BlockPos(x,170,100),Blocks.AIR.defaultBlockState(),3);int d=c.equals("stone4")?4:c.equals("stone8")||c.equals("leaves8")||c.equals("glass8")?8:c.equals("stone12")?12:0;if(d>0)l.setBlock(sensor.east(d),c.equals("leaves8")?Blocks.OAK_LEAVES.defaultBlockState():c.equals("glass8")?Blocks.GLASS.defaultBlockState():Blocks.STONE.defaultBlockState(),3);event("Prepared "+c);}
   if(phase==65){var be=l.getBlockEntity(sensor);if(!(be instanceof dev.simulated_team.simulated.content.blocks.lasers.optical_sensor.OpticalSensorBlockEntity opt))throw new IllegalStateException("optical sensor absent");var st=l.getBlockState(sensor);int power=l.getSignal(sensor,Direction.NORTH);double wireless=node.getOutputs().stream().filter(p->p.getName().equals("Echo")).findFirst().map(p->p.getValue()).orElse(-1.0);String id=BuiltInRegistries.BLOCK.getKey(opt.getHitBlock()).toString();String row=tick+","+c+","+opt.hasHit()+","+id+","+opt.getHitBlockDistance()+","+opt.getRange()+","+st.getValue(BlockStateProperties.POWERED)+","+power+","+wireless+"\n";Files.writeString(out.resolve("results.csv"),row,StandardOpenOption.APPEND);event("Sample "+row.trim());}}
  if(tick==150+cases.length*80){Files.writeString(out.resolve("complete.txt"),"Static optical sensor observations; inspect values. No mobile or avoidance claim.\n");server.halt(false);return;}
 }catch(Exception ex){try{Files.createDirectories(out);Files.writeString(out.resolve("error.txt"),"tick="+tick+" "+ex+"\n");}catch(Exception ignored){}ex.printStackTrace();server.halt(false);}}
}
