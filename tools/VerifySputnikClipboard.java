import java.nio.file.*;
import java.io.*;
import net.minecraft.nbt.NbtIo;
import net.minecraft.nbt.CompoundTag;
import java.util.Base64;
import java.nio.charset.StandardCharsets;
import net.minecraft.nbt.TagParser;
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
   if(nodes.size()!=1||!tag.getList("conns",10).isEmpty()) throw new AssertionError("Unexpected graph shape");
   var node=nodes.getCompound(0);
   if(!node.hasUUID("id")||!node.getString("typeId").equals("rocketnautics:lua_script")) throw new AssertionError("Wrong native node identity");
   // Parsing text alone misses StringTag.writeUTF's hard 65535-byte bound.
   var bytes=new ByteArrayOutputStream();
   NbtIo.writeAnyTag(tag,new DataOutputStream(bytes));
   var restored=(CompoundTag)NbtIo.readAnyTag(new DataInputStream(new ByteArrayInputStream(bytes.toByteArray())),net.minecraft.nbt.NbtAccounter.unlimitedHeap());
   if(!restored.equals(tag)) throw new AssertionError("Binary NBT round-trip changed graph");
   if(!node.getCompound("customData").getString("code").equals(Files.readString(Path.of(args[i+1])))) throw new AssertionError("SNBT changed Lua source");
  }
  System.out.println("Minecraft SNBT: "+args.length/2+" native clipboard nodes parsed AND binary-serialized; old 108508-byte failure reproduced, UUID and Lua round-trips exact");
 }
}
