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
    if(!part.hasUUID("id")||!part.getString("typeId").equals("rocketnautics:lua_script")||ids.put(part.getUUID("id"),part)!=null) throw new AssertionError("Invalid native node");
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
