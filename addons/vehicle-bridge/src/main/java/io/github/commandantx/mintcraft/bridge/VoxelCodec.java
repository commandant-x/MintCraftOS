package io.github.commandantx.mintcraft.bridge;
/** Lossless sparse run encoding, x + 16*z + 256*y; zero is measured air. */
final class VoxelCodec {
    private VoxelCodec() {}
    static String encode(int[] cells) {
        if(cells.length!=4096) throw new IllegalArgumentException("section size");
        var out=new StringBuilder();
        for(int i=0;i<cells.length;) {
            int start=i, value=cells[i++];
            if(value<0 || value>4096) throw new IllegalArgumentException("palette index");
            while(i<cells.length && cells[i]==value) i++;
            if(value!=0) out.append(start).append(':').append(i-start).append(':').append(value).append(';');
        }
        return out.toString();
    }
}
