package io.github.commandantx.mintcraft.bridge;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.objectweb.asm.*;
import static org.junit.jupiter.api.Assertions.*;
class TerrainReadOnlyTest {
    @Test void onlyLoadedWorldReadsNoShapeQueriesWorldWritesOrChunkRequests() throws IOException {
        var calls=new ArrayList<String>(); var publicMethods=new java.util.HashSet<String>(); var main=new ArrayList<Boolean>();
        try(var stream=getClass().getResourceAsStream("TerrainApi.class")) {
            new ClassReader(stream).accept(new ClassVisitor(Opcodes.ASM9) {
                @Override public MethodVisitor visitMethod(int access,String name,String desc,String signature,String[] exceptions) {
                    if((access&Opcodes.ACC_PUBLIC)!=0) publicMethods.add(name);
                    return new MethodVisitor(Opcodes.ASM9) {
                        @Override public void visitMethodInsn(int opcode,String owner,String method,String d,boolean iface) {
                            calls.add(owner+"#"+method);
                            assertFalse(Set.of("getChunk","setBlock","getCollisionShape","getHeight","assemble","disassemble","setAnalogOutput","sendLinkSignal","getBlockEntity").contains(method),method);
                            if(method.equals("getBlockState")) assertEquals("net/minecraft/world/level/chunk/LevelChunk",owner);
                            if(method.equals("getChunkNow")) assertEquals("net/minecraft/server/level/ServerChunkCache",owner);
                        }
                        @Override public void visitFieldInsn(int opcode,String owner,String field,String d) {
                            if(opcode==Opcodes.PUTFIELD||opcode==Opcodes.PUTSTATIC) assertEquals("io/github/commandantx/mintcraft/bridge/TerrainApi",owner);
                        }
                        @Override public AnnotationVisitor visitAnnotation(String d,boolean visible) {
                            if(!d.equals("Ldan200/computercraft/api/lua/LuaFunction;")||(!name.equals("context")&&!name.equals("terrainPage"))) return null;
                            return new AnnotationVisitor(Opcodes.ASM9) { @Override public void visit(String k,Object v) { if(k.equals("mainThread")) main.add(Boolean.TRUE.equals(v)); } };
                        }
                    };
                }
            },0);
        }
        assertEquals(Set.of("<init>","getNames","status","context","terrainPage"),publicMethods);
        assertEquals(java.util.List.of(true,true),main);
        assertTrue(calls.stream().anyMatch(s->s.endsWith("#getChunkNow")));
        assertFalse(calls.stream().anyMatch(s->s.endsWith("#getLoadedChunks")),"vehicle plot must not become world terrain");
    }
}
