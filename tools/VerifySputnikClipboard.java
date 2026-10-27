import java.nio.file.*;
import java.io.*;
import net.minecraft.nbt.NbtIo;
import net.minecraft.nbt.CompoundTag;
import java.util.Base64;
import java.nio.charset.StandardCharsets;
import net.minecraft.nbt.TagParser;
import java.util.*;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.core.BlockPos;
import io.netty.buffer.Unpooled;
/** Parse generated clipboard with the actual mapped Minecraft 1.21.1 SNBT parser. */
public final class VerifySputnikClipboard {
 public static void main(String[] args) throws Exception {
  if(Boolean.getBoolean("mintcraft.sputnik.payload")) {
     // Headless fixture: use the real dedicated-server layout branch.
     Class<?> distType=Class.forName("net.neoforged.api.distmarker.Dist");
     @SuppressWarnings({"unchecked","rawtypes"}) Object dedicated=Enum.valueOf((Class)distType,"DEDICATED_SERVER");
     var distField=Class.forName("net.neoforged.fml.loading.FMLLoader").getDeclaredField("dist");
     distField.setAccessible(true);distField.set(null,dedicated);
  }
  if(Boolean.getBoolean("mintcraft.sputnik.payload")) {
   // Real native selector persistence, not a Lua mock of a dropdown.
   Class<?> slider=Class.forName("dev.devce.websnodelib.api.elements.WSlider");
   var ctor=slider.getConstructor(String.class,double.class,double.class,int.class);
   for(int choice=1;choice<=4;choice++) {
    Object original=ctor.newInstance("Architecture",1.0,4.0,360);
    slider.getMethod("setValue",double.class).invoke(original,(double)choice);
    CompoundTag saved=(CompoundTag)slider.getMethod("save").invoke(original);
    Object restored=ctor.newInstance("Architecture",1.0,4.0,360);
    slider.getMethod("load",CompoundTag.class).invoke(restored,saved);
    if(((Number)slider.getMethod("getValue").invoke(restored)).doubleValue()!=choice) throw new AssertionError("Native architecture selection not persisted");
   }
  }
  if(Boolean.getBoolean("mintcraft.sputnik.payload")) {
   // The actual host keeps an existing node/evaluator when loading unchanged UUID/code.
   // A committed widget update must not reset Lua flight state.
   Class<?> nodeType=Class.forName("dev.devce.websnodelib.api.WNode");
   Object node=nodeType.getConstructor(net.minecraft.resources.ResourceLocation.class,String.class,int.class,int.class).newInstance(net.minecraft.resources.ResourceLocation.parse("rocketnautics:lua_script"),"Persistence fixture",0,0);
   Class<?> graphType=Class.forName("dev.devce.websnodelib.api.WGraph");
   Object graph=graphType.getConstructor().newInstance();graphType.getMethod("addNode",nodeType).invoke(graph,node);
   Class.forName("dev.devce.rocketnautics.registry.RocketNodes").getMethod("setupLuaEvaluatorPublic",nodeType).invoke(null,node);
   CompoundTag data=(CompoundTag)nodeType.getMethod("getCustomData").invoke(node);
   data.putString("code","_G.flightCounter=(_G.flightCounter or 0)+1\noutput('Counter',_G.flightCounter)");
   nodeType.getMethod("evaluate").invoke(node);
   CompoundTag saved=(CompoundTag)graphType.getMethod("save").invoke(graph);
   graphType.getMethod("load",CompoundTag.class).invoke(graph,saved);
   nodeType.getMethod("evaluate").invoke(node);
   var pins=(java.util.List<?>)nodeType.getMethod("getOutputs").invoke(node);
   if(((Number)pins.get(0).getClass().getMethod("getValue").invoke(pins.get(0))).doubleValue()!=2) throw new AssertionError("Actual graph save/load reset unchanged Lua controller");
   // Changing source recreates globals; a fresh graph never restores runtime state.
   data=(CompoundTag)nodeType.getMethod("getCustomData").invoke(node);
   data.putString("code",data.getString("code")+"\n-- source revision");
   nodeType.getMethod("evaluate").invoke(node);
   pins=(java.util.List<?>)nodeType.getMethod("getOutputs").invoke(node);
   if(((Number)pins.get(0).getClass().getMethod("getValue").invoke(pins.get(0))).doubleValue()!=1) throw new AssertionError("Changed source kept old Lua globals");
   Object restarted=graphType.getConstructor().newInstance();
   // A standalone harness has no registered Minecraft node factory. Construct
   // the fresh evaluator as the game factory does, then load its persisted tag.
   Object restored=nodeType.getConstructor(net.minecraft.resources.ResourceLocation.class,String.class,int.class,int.class).newInstance(net.minecraft.resources.ResourceLocation.parse("rocketnautics:lua_script"),"Restart fixture",0,0);
   Class.forName("dev.devce.rocketnautics.registry.RocketNodes").getMethod("setupLuaEvaluatorPublic",nodeType).invoke(null,restored);
   nodeType.getMethod("load",CompoundTag.class).invoke(restored,saved.getList("nodes",10).getCompound(0));
   graphType.getMethod("addNode",nodeType).invoke(restarted,restored);
   graphType.getMethod("load",CompoundTag.class).invoke(restarted,saved);
   nodeType.getMethod("evaluate").invoke(restored);
   pins=(java.util.List<?>)nodeType.getMethod("getOutputs").invoke(restored);
   if(((Number)pins.get(0).getClass().getMethod("getValue").invoke(pins.get(0))).doubleValue()!=1) throw new AssertionError("Graph restart restored active Lua runtime");
  }
  if(Boolean.getBoolean("mintcraft.sputnik.payload")) {
   // Compact fields keep a fixed order: verify real native widget persistence,
   // not just serialization of empty clipboard placeholders.
   Class<?> nt=Class.forName("dev.devce.websnodelib.api.WNode");
   Class<?> gt=Class.forName("dev.devce.websnodelib.api.WGraph");
   Class<?> factory=Class.forName("dev.devce.rocketnautics.registry.RocketNodes");
   Object graph=gt.getConstructor().newInstance();
   Object node=nt.getConstructor(net.minecraft.resources.ResourceLocation.class,String.class,int.class,int.class).newInstance(net.minecraft.resources.ResourceLocation.parse("rocketnautics:lua_script"),"Compact form persistence",0,0);
   gt.getMethod("addNode",nt).invoke(graph,node);factory.getMethod("setupLuaEvaluatorPublic",nt).invoke(null,node);
   // Item registries require a running mod loader. Keep frequency pickers inert
   // here; LuaJ graph fixtures separately cover their import/export values.
   String code="ui.itempicker=function() return {getItem=function() return nil end,setItem=function() end} end\n"+Files.readString(Path.of("platforms/sputnik/dist/mintcraft-mount-simple.lua"));
   ((CompoundTag)nt.getMethod("getCustomData").invoke(node)).putString("code",code);nt.getMethod("evaluate").invoke(node);
   if(((CompoundTag)nt.getMethod("getCustomData").invoke(node)).getBoolean("err")) throw new AssertionError("Actual compact form evaluation failed: "+((CompoundTag)nt.getMethod("getCustomData").invoke(node)).getString("errMsg"));
   var elements=(java.util.List<?>)nt.getMethod("getElements").invoke(node);
   var fields=new java.util.ArrayList<Object>();
   for(Object element:elements) if(element.getClass().getSimpleName().equals("WTextField")) fields.add(element);
   String[] expected={"224","16","2","-4","1","6","gain=20;neutral=7;fallback=15;run=15","MCV1 copy retained"};
   if(fields.size()!=expected.length) throw new AssertionError("Unexpected compact widget order");
   for(int j=0;j<expected.length;j++) fields.get(j).getClass().getMethod("setValue",String.class).invoke(fields.get(j),expected[j]);
   for(Object element:elements) if(element.getClass().getSimpleName().equals("WSlider")) element.getClass().getMethod("setValue",double.class).invoke(element,2.0);
   CompoundTag saved=(CompoundTag)nt.getMethod("save").invoke(node);
   Object freshGraph=gt.getConstructor().newInstance();
   Object fresh=nt.getConstructor(net.minecraft.resources.ResourceLocation.class,String.class,int.class,int.class).newInstance(net.minecraft.resources.ResourceLocation.parse("rocketnautics:lua_script"),"Compact reload",0,0);
   gt.getMethod("addNode",nt).invoke(freshGraph,fresh);factory.getMethod("setupLuaEvaluatorPublic",nt).invoke(null,fresh);
   ((CompoundTag)nt.getMethod("getCustomData").invoke(fresh)).putString("code",code);nt.getMethod("evaluate").invoke(fresh);
   nt.getMethod("load",CompoundTag.class).invoke(fresh,saved);nt.getMethod("evaluate").invoke(fresh);
   fields.clear();for(Object element:(java.util.List<?>)nt.getMethod("getElements").invoke(fresh)) if(element.getClass().getSimpleName().equals("WTextField")) fields.add(element);
   for(int j=0;j<expected.length;j++) if(!fields.get(j).getClass().getMethod("getValue").invoke(fields.get(j)).equals(expected[j])) throw new AssertionError("Compact reload lost field "+j);
   System.out.println("Native compact form: source RPM, sails, shared members, XYZ, expert parameters and copy field retained across fresh evaluator reload");
  }
  if(Boolean.getBoolean("mintcraft.sputnik.payload")) {
   Class<?> nt=Class.forName("dev.devce.websnodelib.api.WNode"),gt=Class.forName("dev.devce.websnodelib.api.WGraph"),factory=Class.forName("dev.devce.rocketnautics.registry.RocketNodes");
   Object graph=gt.getConstructor().newInstance();
   Object node=nt.getConstructor(net.minecraft.resources.ResourceLocation.class,String.class,int.class,int.class).newInstance(net.minecraft.resources.ResourceLocation.parse("rocketnautics:lua_script"),"Workbench persistence",0,0);
   gt.getMethod("addNode",nt).invoke(graph,node);factory.getMethod("setupLuaEvaluatorPublic",nt).invoke(null,node);
   String code="ui.itempicker=function() return {getItem=function() return nil end,setItem=function() end} end\n"+Files.readString(Path.of("platforms/sputnik/dist/mintcraft-mount-workbench.lua"));
   ((CompoundTag)nt.getMethod("getCustomData").invoke(node)).putString("code",code);nt.getMethod("evaluate").invoke(node);
   var fields=new java.util.ArrayList<Object>();
   for(Object element:(java.util.List<?>)nt.getMethod("getElements").invoke(node)) if(element.getClass().getSimpleName().equals("WTextField")) fields.add(element);
   if(fields.size()!=15) throw new AssertionError("Unexpected workbench field order: "+fields.size());
   // Save immediately after a final keystroke, before the editor's next evaluation.
   fields.get(0).getClass().getMethod("setValue",String.class).invoke(fields.get(0),"224");
   fields.get(1).getClass().getMethod("setValue",String.class).invoke(fields.get(1),"24");
   CompoundTag saved=(CompoundTag)nt.getMethod("save").invoke(node);
   Object freshGraph=gt.getConstructor().newInstance(),fresh=nt.getConstructor(net.minecraft.resources.ResourceLocation.class,String.class,int.class,int.class).newInstance(net.minecraft.resources.ResourceLocation.parse("rocketnautics:lua_script"),"Workbench reload",0,0);
   gt.getMethod("addNode",nt).invoke(freshGraph,fresh);factory.getMethod("setupLuaEvaluatorPublic",nt).invoke(null,fresh);
   ((CompoundTag)nt.getMethod("getCustomData").invoke(fresh)).putString("code",code);nt.getMethod("evaluate").invoke(fresh);
   nt.getMethod("load",CompoundTag.class).invoke(fresh,saved);nt.getMethod("evaluate").invoke(fresh);
   CompoundTag data=(CompoundTag)nt.getMethod("getCustomData").invoke(fresh);
   if(data.getBoolean("err")) throw new AssertionError("Workbench reload: "+data.getString("errMsg"));
   fields.clear();for(Object element:(java.util.List<?>)nt.getMethod("getElements").invoke(fresh)) if(element.getClass().getSimpleName().equals("WTextField")) fields.add(element);
   if(!fields.get(0).getClass().getMethod("getValue").invoke(fields.get(0)).equals("224") || !fields.get(1).getClass().getMethod("getValue").invoke(fields.get(1)).equals("24")) throw new AssertionError("Workbench lost pending last keystroke on fresh NBT reload");
   System.out.println("Native workbench: pending last keystroke survives actual NBT save/fresh evaluator reload");
  }
  // Reproduce the user's 108508-byte failure in the real NBT binary writer.
  var oversized=new CompoundTag(); oversized.putString("code","x".repeat(108508));
  try {
   NbtIo.writeAnyTag(oversized,new DataOutputStream(new ByteArrayOutputStream()));
   throw new AssertionError("Oversized historical source unexpectedly serialized");
  } catch(UTFDataFormatException expected) { }
  try { new DataOutputStream(new ByteArrayOutputStream()).writeUTF("x".repeat(65536)); throw new AssertionError("Java UTF limit changed"); }
  catch(UTFDataFormatException expected) { }
  new DataOutputStream(new ByteArrayOutputStream()).writeUTF("x".repeat(65535));
  for(int i=0;i<args.length;i+=2) {
   String encoded=Files.readString(Path.of(args[i]));
   // Match Sputnik's strict decoder exactly: never trim away a bad artifact.
   if(encoded.chars().anyMatch(Character::isWhitespace)) throw new AssertionError("Whitespace in native Base64 artifact");
   try { Base64.getDecoder().decode(encoded+"\n"); throw new AssertionError("Strict decoder unexpectedly accepted trailing newline"); }
   catch(IllegalArgumentException expected) { }
   var tag=TagParser.parseTag(new String(Base64.getDecoder().decode(encoded),StandardCharsets.UTF_8));
   var nodes=tag.getList("nodes",10);
   boolean multi=args[i+1].startsWith("@graph");
   String[] shape=args[i+1].split(":");
   int expectedNodes=multi?(shape.length==3?Integer.parseInt(shape[1]):4):1;
   int expectedEdges=multi?(shape.length==3?Integer.parseInt(shape[2]):20):0;
   if(nodes.size()!=expectedNodes||tag.getList("conns",10).size()!=expectedEdges) throw new AssertionError("Unexpected graph shape");
   var ids=new HashMap<UUID,CompoundTag>();
   for(int n=0;n<nodes.size();n++) {
    var part=nodes.getCompound(n);
    if(!part.hasUUID("id")||!Set.of("rocketnautics:lua_script","websnodelib:string_display").contains(part.getString("typeId"))||ids.put(part.getUUID("id"),part)!=null) throw new AssertionError("Invalid native node");
    if(part.getString("typeId").equals("websnodelib:string_display")&&Boolean.getBoolean("mintcraft.sputnik.payload")) {
     Class.forName("dev.devce.websnodelib.internal.InternalNodes").getMethod("register").invoke(null);
     Class<?> registry=Class.forName("dev.devce.websnodelib.api.NodeRegistry");
     Object actual=registry.getMethod("createNode",net.minecraft.resources.ResourceLocation.class,int.class,int.class).invoke(null,net.minecraft.resources.ResourceLocation.parse("websnodelib:string_display"),0,0);
     var inputs=(java.util.List<?>)actual.getClass().getMethod("getInputs").invoke(actual);
     if(inputs.size()!=1||!inputs.get(0).getClass().getMethod("getValueType").invoke(inputs.get(0)).toString().equals("STRING")) throw new AssertionError("Actual String Display input changed");
     actual.getClass().getMethod("load",CompoundTag.class).invoke(actual,part);
     inputs=(java.util.List<?>)actual.getClass().getMethod("getInputs").invoke(actual);
     inputs.get(0).getClass().getMethod("setStringValue",String.class).invoke(inputs.get(0),"Diagnostic serveur");
     actual.getClass().getMethod("evaluate").invoke(actual);
    }
    new DataOutputStream(new ByteArrayOutputStream()).writeUTF(part.getCompound("customData").getString("code"));
   }
   var links=tag.getList("conns",10);
   for(int n=0;n<links.size();n++) {
    var link=links.getCompound(n);var src=ids.get(link.getUUID("src"));var tgt=ids.get(link.getUUID("tgt"));
    if(src==null||tgt==null||link.getInt("srcP")<0||link.getInt("tgtP")<0||link.getInt("srcP")>=src.getList("outputs",10).size()||link.getInt("tgtP")>=tgt.getList("inputs",10).size()) throw new AssertionError("Broken graph connection");
    var a=src.getList("outputs",10).getCompound(link.getInt("srcP"));var b=tgt.getList("inputs",10).getCompound(link.getInt("tgtP"));
    if(!a.getString("valueType").equals(b.getString("valueType"))) throw new AssertionError("Pin type mismatch");
   }
   var node=nodes.getCompound(0);
   if(!node.hasUUID("id")||!node.getString("typeId").equals("rocketnautics:lua_script")) throw new AssertionError("Wrong native node identity");
   // Parsing text alone misses StringTag.writeUTF's hard 65535-byte bound.
   var bytes=new ByteArrayOutputStream();
   NbtIo.writeAnyTag(tag,new DataOutputStream(bytes));
   var restored=(CompoundTag)NbtIo.readAnyTag(new DataInputStream(new ByteArrayInputStream(bytes.toByteArray())),net.minecraft.nbt.NbtAccounter.unlimitedHeap());
   if(!restored.equals(tag)) throw new AssertionError("Binary NBT round-trip changed graph");
   if(!multi&&!node.getCompound("customData").getString("code").equals(Files.readString(Path.of(args[i+1])))) throw new AssertionError("SNBT changed Lua source");
   if(Boolean.getBoolean("mintcraft.sputnik.payload")) {
    Class<?> type=Class.forName("dev.devce.rocketnautics.network.SputnikNodeSyncPayload");
    Object message=type.getConstructor(BlockPos.class,CompoundTag.class).newInstance(BlockPos.ZERO,tag);
    @SuppressWarnings("unchecked") var codec=(StreamCodec<FriendlyByteBuf,Object>)type.getField("CODEC").get(null);
    var buffer=new FriendlyByteBuf(Unpooled.buffer());
    try { codec.encode(buffer,message);Object decoded=codec.decode(buffer);if(!tag.equals(type.getMethod("graphData").invoke(decoded))) throw new AssertionError("Actual Sputnik payload changed graph"); }
    finally { buffer.release(); }
   }
  }
  System.out.println("Minecraft SNBT: "+args.length/2+" clipboard artifacts parsed AND binary-serialized; old 108508-byte failure reproduced, UUID/Lua/pin links round-trip exact; optional actual Sputnik CODEC");
 }
}
