package io.github.commandantx.mintcraft.bridge;
final class StructureHash {
 private StructureHash() {}
 static String state(String block,java.util.Map<String,String> properties) {
  var out=new StringBuilder(block);
  new java.util.TreeMap<>(properties).forEach((key,value)->{
   if(!java.util.Set.of("powered","power","lit").contains(key)) out.append('|').append(key).append('=').append(value);
  });
  return out.toString();
 }
 static String digest(String value) {
  try { return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8))); }
  catch(java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
 }
}
