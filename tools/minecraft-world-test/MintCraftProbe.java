package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.tick.ServerTickEvent;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.LeverBlock;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.item.ItemStack;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import dev.ryanhcode.sable.api.sublevel.SubLevelContainer;
import dev.ryanhcode.sable.sublevel.ServerSubLevel;
import dev.devce.rocketnautics.content.blocks.SputnikBlockEntity;
import dev.devce.websnodelib.api.*;
import dev.devce.websnodelib.api.elements.*;
import dev.eriksonn.aeronautics.content.blocks.propeller.bearing.propeller_bearing.PropellerBearingBlockEntity;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;
import java.nio.file.*;
import java.util.*;
@Mod("mintcraft_probe")
public class MintCraftProbe {
 private int ticks,release=-1;private final int endTick=Integer.getInteger("mintcraft.test.endTick",4000);private final Path root=Path.of("mintcraft-flight-test");private ServerSubLevel ship;private SputnikBlockEntity sp;private BlockPos lever;private List<PropellerBearingBlockEntity> rotors=new ArrayList<>();private List<BlockEntity> links=new ArrayList<>();private List<String[]> rotorLinks=new ArrayList<>();private List<com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity> receivers=new ArrayList<>();private WNode controller,setup,commands;private boolean aborted;private int ackRevision;private int exportPage=1,exportTotal;
 private static final UUID TARGET=UUID.fromString("b1b77b66-af45-46cf-baff-ca16d1d1ce34");
 private final String[] keys={"blue_wool","brown_wool","red_wool","lime_wool","white_wool","black_wool"};
 public MintCraftProbe(){NeoForge.EVENT_BUS.addListener(this::tick);}
 private List<WTextField> fields(WNode n){return n.getElements().stream().filter(x->x instanceof WTextField).map(x->(WTextField)x).toList();}
 private String output(WNode n,String name){return n.getOutputs().stream().filter(x->x.getName().equals(name)).findFirst().map(WPin::getValueAsString).orElse("?");}
 private WNode node(String suffix){return sp.graph.getNodes().stream().filter(n->n.getTitle().endsWith(suffix)).findFirst().orElseThrow();}
 private void event(String message)throws Exception{Files.writeString(root.resolve("events.tsv"),ticks+"\t"+message+"\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND);System.out.println("MINTCRAFT_TEST "+ticks+" "+message);}
 private void power(boolean on){ServerLevel l=ship.getLevel();var state=l.getBlockState(lever);if(!(state.getBlock() instanceof LeverBlock))throw new IllegalStateException("Enable lever missing");l.setBlock(lever,state.setValue(BlockStateProperties.POWERED,on),3);}
 private void prepare(MinecraftServer server)throws Exception{
  for(ServerLevel level:server.getAllLevels()){var s=SubLevelContainer.getContainer(level).getSubLevel(TARGET);if(s instanceof ServerSubLevel ss){ship=ss;break;}}
  if(ship==null)throw new IllegalStateException("Target sublevel not loaded");
  for(var holder:ship.getPlot().getLoadedChunks())for(BlockEntity be:holder.getChunk().getBlockEntities().values()){
   if(be instanceof SputnikBlockEntity s)sp=s;
   if(be instanceof PropellerBearingBlockEntity b)rotors.add(b);
   if(BuiltInRegistries.BLOCK_ENTITY_TYPE.getKey(be.getType()).toString().equals("create:redstone_link"))links.add(be);
  }
  if(sp==null||rotors.size()!=4)throw new IllegalStateException("Expected four bearings and Sputnik");
  rotors.sort(Comparator.comparingInt((PropellerBearingBlockEntity b)->-b.getBlockPos().getZ()).thenComparingInt(b->b.getBlockPos().getX()));
  var center=ship.getMassTracker().getCenterOfMass();var bounds=ship.getPlot().getBoundingBox();double radius=0;
  for(int x:new int[]{bounds.minX(),bounds.maxX()})for(int y:new int[]{bounds.minY(),bounds.maxY()})for(int z:new int[]{bounds.minZ(),bounds.maxZ()})radius=Math.max(radius,center.distance(x,y,z));
  StringBuilder descriptors=new StringBuilder(),hardware=new StringBuilder("id\tx\ty\tz\tsails\tshaft_rpm\tthrust\tairflow\tfrequency\n");int id=0;Set<BlockEntity> used=new HashSet<>();
  for(var b:rotors){
   id++;var pos=b.getBlockPos();if(b.totalSailPower<1||b.totalSailPower!=Math.rint(b.totalSailPower)||b.getScaledThrust()*b.getBlockDirection().getStepY()<=0||Math.abs(b.getSpeed())!=256)throw new IllegalStateException("Unverified bearing model "+pos+" sails="+b.totalSailPower+" speed="+b.getSpeed());
   BlockEntity nearest=null;double distance=Double.POSITIVE_INFINITY;
   for(var link:links){var tag=link.saveWithFullMetadata(server.registryAccess());if(tag.getBoolean("Transmitter"))continue;double d=pos.distSqr(link.getBlockPos());if(d<distance){distance=d;nearest=link;}}
   if(nearest==null||distance>16||!used.add(nearest))throw new IllegalStateException("Ambiguous actuator link mapping");
   var tag=nearest.saveWithFullMetadata(server.registryAccess());String first=tag.getCompound("FrequencyFirst").getString("id"),second=tag.getCompound("FrequencyLast").getString("id");rotorLinks.add(new String[]{first,second});receivers.add((com.simibubi.create.content.redstone.link.RedstoneLinkBlockEntity)nearest);
   double x=pos.getX()+.5-center.x(),y=pos.getY()+.5-center.y(),z=pos.getZ()+.5-center.z();
   if(id>1)descriptors.append('\n');descriptors.append("MCV1;").append(id).append(";bearing;lift;").append(x).append(';').append(y).append(';').append(z).append(";0;1;0;256;").append((int)b.totalSailPower).append(";0.2;0.05;1;8;-1;1;").append(first).append(';').append(second).append(";;;;;0;0.15;0;1");
   hardware.append(id).append('\t').append(pos.getX()).append('\t').append(pos.getY()).append('\t').append(pos.getZ()).append('\t').append(b.totalSailPower).append('\t').append(b.getDirectionIndependentSpeed()).append('\t').append(b.getThrust()).append('\t').append(b.getAirflow()).append('\t').append(first+","+second).append('\n');
  }
  Files.writeString(root.resolve("flight.csv"),"tick,universe_tick,x,y,z,pitch,yaw,roll,vx,vy,vz,target_y,active,rpm1,rpm2,rpm3,rpm4,rx1,rx2,rx3,rx4\n");Files.writeString(root.resolve("descriptors.txt"),descriptors);Files.writeString(root.resolve("hardware.tsv"),hardware);Files.writeString(root.resolve("geometry.txt"),"mass="+ship.getMassTracker().getMass()+" COM="+center+" bounds="+bounds+" radius="+(radius+1)+" inertia="+ship.getMassTracker().getInertiaTensor()+"\n");
  for(var link:links){var t=link.saveWithFullMetadata(server.registryAccess());if(t.getBoolean("Transmitter")&&t.getCompound("FrequencyFirst").getString("id").equals("minecraft:magenta_wool")&&t.getCompound("FrequencyLast").getString("id").equals("minecraft:magenta_wool")){
   for(BlockPos p:BlockPos.betweenClosed(link.getBlockPos().offset(-2,-2,-2),link.getBlockPos().offset(2,2,2)))if(ship.getLevel().getBlockState(p).getBlock() instanceof LeverBlock){if(lever!=null)throw new IllegalStateException("Multiple Enable levers");lever=p.immutable();}
  }}
  if(lever==null)throw new IllegalStateException("Physical Enable lever not found");power(false);
  var enable=node("-enable");for(var e:enable.getElements())if(e instanceof WItemPicker p)p.setStack(new ItemStack(net.minecraft.world.item.Items.MAGENTA_WOOL));
  setup=node("-montage");var f=fields(setup);if(f.size()!=5)throw new IllegalStateException("Setup field contract changed");f.get(0).setValue("11");f.get(1).setValue("4");f.get(2).setValue("20");f.get(3).setValue(Double.toString(radius+1));f.get(4).setValue("4");for(var e:setup.getElements())if(e instanceof WCheckbox box)box.setChecked(true);setup.getElements().stream().filter(e->e instanceof WCheckbox).map(e->(WCheckbox)e).toList().get(3).setChecked(false);
  fields(node("-mount")).get(8).setValue(descriptors.toString());
  var keyboard=node("-keyboard");int k=0;for(var e:keyboard.getElements())if(e instanceof WItemPicker p){String item="minecraft:"+keys[k++/2];p.setStack(new ItemStack(BuiltInRegistries.ITEM.get(ResourceLocation.parse(item))));}else if(e instanceof WCheckbox box)box.setChecked(true);
  node("-operations").getElements().clear();node("-operations").getCustomData().putString("code",Files.readString(Path.of("mintcraft-operations.lua")));controller=node("-autopilot");controller.getElements().clear();controller.getCustomData().putString("code",Files.readString(Path.of("mintcraft-controller.lua")));commands=node("-commands");event("PREPARED: independent shaft/link mapping, measured geometry, physical Enable OFF; original controller retained");
 }
 private void driver()throws Exception{
  long base=sp.getUniverseTime()+200;StringBuilder lua=new StringBuilder("local t=getUniverseTime()-"+base+"\nlocal a={0,0,0,0,0,0}\n");
  lua.append("if t>=400 and t<420 then a[5]=15 elseif t>=820 and t<840 then a[6]=15 elseif t>=1240 and t<1260 then a[1]=15 elseif t>=1660 and t<1680 then a[2]=15 elseif t>=2080 and t<2100 then a[3]=15 elseif t>=2500 and t<2520 then a[4]=15 elseif t>=2920 and t<2940 then a[1]=15;a[3]=15 end\n");
  for(int i=0;i<6;i++)lua.append("transmitWirelessRedstone('minecraft:").append(keys[i]).append("','minecraft:").append(keys[i]).append("',a[").append(i+1).append("])\n");
  lua.append("output('Scenario tick',t)\n");var n=new WNode(ResourceLocation.parse("rocketnautics:lua_script"),"Test fixture: six key radio transmitter",20,1200);dev.devce.rocketnautics.registry.RocketNodes.setupLuaEvaluatorPublic(n);n.getCustomData().putString("code",lua.toString());sp.graph.addNode(n);event("DRIVER: synthetic six-key radio; no actuator outputs; scenario epoch="+base);
 }
 private void tick(ServerTickEvent.Post event){
  MinecraftServer server=event.getServer();ticks++;
  try {
   Files.createDirectories(root);if(ticks==20)server.getCommands().performPrefixedCommand(server.createCommandSourceStack(),"forceload add -96 96 32 224");
   if(ticks==120)prepare(server);
   if(sp!=null){
    if(ticks==160){if(fields(node("-operations")).size()!=5||node("-operations").getElements().size()!=18||fields(controller).size()!=1)throw new IllegalStateException("Stale UI elements after source replacement");Files.writeString(root.resolve("configured-graph.snbt"),sp.graph.save().toString());event("STATUS "+output(controller,"Status"));}
    if(ticks==200)power(true);
    if(ticks==300){event("WARMUP "+output(controller,"Status"));if(Double.parseDouble(output(controller,"Active"))!=1)throw new IllegalStateException("Controller not armed: "+output(controller,"Status"));power(false);}
    if(ticks==310){driver();power(true);}
    if(ticks==320){if(Double.parseDouble(output(controller,"Active"))!=1)throw new IllegalStateException("Controller not rearmed: "+output(controller,"Status"));var staff=PhysicsStaffServerHandler.get(ship.getLevel());if(!staff.isLocked(ship))throw new IllegalStateException("Expected locked test setup");staff.removeLock(ship);release=ticks;event("RELEASE: fixture lock removed, physical flight begins");}
    if(ticks>=1300 && (ticks-1300)%420==0 && output(node("-operations"),"Stop horizontal").equals("1.0")){
     fields(node("-operations")).get(3).setValue("MCREC1;"+(++ackRevision)+";ACK");event("ACK_REQUEST after settling; server decides stability");
    }
    if(ticks>=120){
     var v=sp.getVelocityVector();StringBuilder row=new StringBuilder().append(ticks).append(',').append(sp.getUniverseTime()).append(',').append(sp.getX()).append(',').append(sp.getY()).append(',').append(sp.getZ()).append(',').append(sp.getPitch()).append(',').append(sp.getYaw()).append(',').append(sp.getRoll()).append(',').append(v.x).append(',').append(v.y).append(',').append(v.z).append(',').append(output(controller,"Target altitude")).append(',').append(output(controller,"Active"));
     for(var rotor:rotors)row.append(',').append(Math.abs(rotor.getDirectionIndependentSpeed()));for(var rx:receivers)row.append(',').append(rx.getReceivedSignal());row.append('\n');Files.writeString(root.resolve("flight.csv"),row,StandardOpenOption.CREATE,StandardOpenOption.APPEND);
     Files.writeString(root.resolve("writer-report.txt"),output(controller,"Report"));
     if(ticks%20==0)event("STATUS "+output(controller,"Status"));
    }
    if(release>=0&&ticks<endTick&&!aborted&&(Math.abs(sp.getPitch())>60||Math.abs(sp.getRoll())>60||Math.abs(sp.getAltitude()-106.13)>20||Double.parseDouble(output(controller,"Active"))!=1)){aborted=true;var staff=PhysicsStaffServerHandler.get(ship.getLevel());if(!staff.isLocked(ship))staff.toggleLock(ship.getUniqueId());power(false);event("ABORT: test envelope exceeded; fixture locked; not a flight pass");Files.writeString(root.resolve("final-graph.snbt"),sp.graph.save().toString());server.halt(false);}
   }
   if(ticks==endTick){if(ship!=null&&!PhysicsStaffServerHandler.get(ship.getLevel()).isLocked(ship))PhysicsStaffServerHandler.get(ship.getLevel()).toggleLock(ship.getUniqueId());if(sp!=null){power(false);Files.writeString(root.resolve("final-graph.snbt"),sp.graph.save().toString());}fields(node("-operations")).get(3).setValue("MCREC1;"+(++ackRevision)+";FULL");event("COMPLETE: scenario ended, criteria scored separately");}
   if(ticks>=endTick+10 && ticks<endTick+45 && sp!=null){
   WNode operations=node("-operations");String page=fields(operations).get(1).getValue();String[] head=page.lines().findFirst().orElse("").split(";");
   if(head.length==9 && head[0].equals("MCLOG1")){exportTotal=Integer.parseInt(head[4]);int current=Integer.parseInt(head[3]);if(current==exportPage){Files.writeString(root.resolve("page-"+exportPage+".txt"),page);exportPage++;}}
   var sliders=operations.getElements().stream().filter(e->e instanceof WSlider).map(e->(WSlider)e).toList();if(exportPage<=exportTotal)sliders.get(1).setValue(exportPage);
  }
  if(ticks==endTick+45){if(exportTotal<1||exportPage!=exportTotal+1)throw new IllegalStateException("Incomplete server log export");event("EXPORT: "+exportTotal+" pages complete");server.halt(false);}
  }catch(Throwable error){try{Files.writeString(root.resolve("error.txt"),error.toString());event("ERROR "+error);}catch(Exception ignored){}error.printStackTrace();server.halt(false);}
 }
}
