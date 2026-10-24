import java.nio.file.*;
import java.util.Base64;
import java.nio.charset.StandardCharsets;
import net.minecraft.nbt.TagParser;
/** Parse generated clipboard with the actual mapped Minecraft 1.21.1 SNBT parser. */
public final class VerifySputnikClipboard {
 public static void main(String[] args) throws Exception {
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
   if(!node.getCompound("customData").getString("code").equals(Files.readString(Path.of(args[i+1])))) throw new AssertionError("SNBT changed Lua source");
  }
  System.out.println("Minecraft SNBT: "+args.length/2+" native clipboard nodes parsed; UUID and Lua bytes round-trip exact");
 }
}
