package io.github.commandantx.mintcraft.bridge;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.objectweb.asm.*;
import static org.junit.jupiter.api.Assertions.*;

class ReadOnlyContractTest {
    @Test void bridgeBytecodeHasNoWorldMutatorsOrChunkLoading() throws IOException {
        var calls=new ArrayList<String>();
        var methods=new ArrayList<String>();
        try(var stream=getClass().getResourceAsStream("VehicleApi.class")) {
            assertNotNull(stream);
            new ClassReader(stream).accept(new ClassVisitor(Opcodes.ASM9) {
                @Override public MethodVisitor visitMethod(int access,String name,String desc,String sig,String[] exceptions) {
                    if((access&Opcodes.ACC_PUBLIC)!=0) methods.add(name);
                    return new MethodVisitor(Opcodes.ASM9) {
                        @Override public void visitMethodInsn(int opcode,String owner,String method,String descriptor,boolean iface) {
                            calls.add(owner+"#"+method);
                            assertFalse(Set.of("setSignal","setAnalogOutput","assemble","disassemble","applyForces",
                                "applyAndRecordPointForce","buildMassTracker","enableIndividualQueuedForcesTracking","setBlock").contains(method),method);
                            if(method.equals("getChunk")) assertEquals("dev/ryanhcode/sable/sublevel/plot/PlotChunkHolder",owner,"unexpected chunk-loading call");
                        }
                        @Override public void visitFieldInsn(int opcode,String owner,String name,String desc) {
                            if(opcode==Opcodes.PUTFIELD || opcode==Opcodes.PUTSTATIC)
                                assertEquals("io/github/commandantx/mintcraft/bridge/VehicleApi",owner,"external field mutation");
                        }
                    };
                }
            },0);
        }
        assertEquals(Set.of("<init>","getNames","status","snapshot","geometryPage","feedback"),Set.copyOf(methods));
        assertTrue(calls.stream().anyMatch(s->s.endsWith("#getLoadedChunks")));
        assertFalse(calls.stream().anyMatch(s->s.contains("#setReceivedStrength")));
    }
    @Test void snapshotIsMainThreadOnly() throws IOException {
        var found=new ArrayList<Boolean>();
        try(var stream=getClass().getResourceAsStream("VehicleApi.class")) {
            new ClassReader(stream).accept(new ClassVisitor(Opcodes.ASM9) {
                @Override public MethodVisitor visitMethod(int access,String name,String desc,String sig,String[] exceptions) {
                    if(!name.equals("snapshot") && !name.equals("geometryPage") && !name.equals("feedback")) return null;
                    return new MethodVisitor(Opcodes.ASM9) {
                        @Override public AnnotationVisitor visitAnnotation(String descriptor,boolean visible) {
                            if(!descriptor.equals("Ldan200/computercraft/api/lua/LuaFunction;")) return null;
                            return new AnnotationVisitor(Opcodes.ASM9) {
                                @Override public void visit(String name,Object value) { if(name.equals("mainThread")) found.add(Boolean.TRUE.equals(value)); }
                            };
                        }
                    };
                }
            },0);
        }
        assertEquals(List.of(true,true,true),found);
    }
}
