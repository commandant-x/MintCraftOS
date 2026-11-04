package io.github.commandantx.mintcraft.sputnik;

import dev.devce.rocketnautics.content.blocks.SputnikBlockEntity;
import dev.devce.websnodelib.api.NodeRegistry;
import dev.devce.websnodelib.api.WNode;
import dev.devce.websnodelib.api.WPin;
import dev.ryanhcode.sable.Sable;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.Mth;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.LevelChunk;
import net.neoforged.fml.common.Mod;

/** Experimental, loaded-static-block scan. Model-specific dimensions, no dynamic bodies. */
@Mod("mintcraft_sputnik_obstacle")
public final class ObstacleSensor {
 public static final ResourceLocation ID=ResourceLocation.fromNamespaceAndPath("mintcraft_sputnik_obstacle","forward_scan");
 public ObstacleSensor(){NodeRegistry.register(ID,"MintCraft",ObstacleSensor::node);}
 private static WNode node(int x,int y){
  WNode n=new WNode(ID,"Terrain avant - quadrupede",x,y);
  for(String s:new String[]{"Valid","Obstacle","Distance","Lateral","Possible tree","Sample tick","Tree evidence valid"})n.addOutput(s,0xFF78C779);
  for(String s:new String[]{"Kind","Block","Status"})n.addOutput(s,0xFFE4D19B,WPin.ValueType.STRING);
  n.setEvaluator(new Scan());return n;
 }
 private static void number(WNode n,String key,double value){n.getOutputs().stream().filter(p->p.getName().equals(key)).findFirst().ifPresent(p->p.setValue(value));}
 private static void text(WNode n,String key,String value){n.getOutputs().stream().filter(p->p.getName().equals(key)).findFirst().ifPresent(p->p.setStringValue(value));}
 private static void unknown(WNode n,String reason){number(n,"Valid",0);number(n,"Obstacle",0);number(n,"Distance",-1);number(n,"Lateral",0);number(n,"Possible tree",0);number(n,"Sample tick",-1);number(n,"Tree evidence valid",0);text(n,"Kind","unknown");text(n,"Block","");text(n,"Status",reason);}
 private static final class Scan implements WNode.Evaluator {
  private long lastTick=Long.MIN_VALUE;
  @Override public void evaluate(WNode n){
   if(n.getParentGraph()==null||!(n.getParentGraph().getContext() instanceof SputnikBlockEntity sp)||!(sp.getLevel() instanceof ServerLevel level)){unknown(n,"NO_SERVER_CONTEXT");return;}
   long tick=level.getGameTime();if(lastTick!=Long.MIN_VALUE&&tick>=lastTick&&tick-lastTick<5)return;lastTick=tick;
   if(Sable.HELPER.getContaining(level,sp.getBlockPos())==null){unknown(n,"NO_SUBLEVEL");return;}
   double cx=sp.getX(),cy=sp.getY(),cz=sp.getZ(),yaw=sp.getYaw();
   if(!Double.isFinite(cx)||!Double.isFinite(cy)||!Double.isFinite(cz)||!Double.isFinite(yaw)){unknown(n,"INVALID_POSE");return;}
   double rad=Math.toRadians(yaw),fx=Math.sin(rad),fz=Math.cos(rad),rx=fz,rz=-fx,pad=(Math.abs(fx)+Math.abs(fz))*.5;
   int y0=Mth.floor(cy)-15,y1=Mth.floor(cy)+2;if(y0<level.getMinBuildHeight()||y1>=level.getMaxBuildHeight()){unknown(n,"HEIGHT_UNKNOWN");return;}
   double best=Double.POSITIVE_INFINITY,bestSide=0;String bestKind="",bestBlock="";BlockPos nearestLog=null,nearestLeaf=null;double logDist=Double.POSITIVE_INFINITY,leafDist=Double.POSITIVE_INFINITY;
   int r=40;for(int x=Mth.floor(cx)-r;x<=Mth.floor(cx)+r;x++)for(int z=Mth.floor(cz)-r;z<=Mth.floor(cz)+r;z++){
    double dx=x+.5-cx,dz=z+.5-cz,f=dx*fx+dz*fz,side=dx*rx+dz*rz;
    if(f+pad<11||f-pad>35||Math.abs(side)>14+pad)continue;
    LevelChunk chunk=level.getChunkSource().getChunkNow(x>>4,z>>4);if(chunk==null){unknown(n,"UNLOADED");return;}
    for(int y=y0;y<=y1;y++){
     BlockPos pos=new BlockPos(x,y,z);BlockState state=chunk.getBlockState(pos);if(state.isAir())continue;
     double distance=Math.max(0,f-pad-11);boolean log=state.is(BlockTags.LOGS),leaf=state.is(BlockTags.LEAVES);String kind=log?"log":leaf?"leaves":"other";
     if(distance<best){best=distance;bestSide=side;bestKind=kind;bestBlock=BuiltInRegistries.BLOCK.getKey(state.getBlock()).toString();}
     if(log&&distance<logDist){nearestLog=pos;logDist=distance;}if(leaf&&distance<leafDist){nearestLeaf=pos;leafDist=distance;}
    }
   }
   boolean tree=nearestLog!=null&&nearestLeaf!=null&&Math.abs(nearestLog.getX()-nearestLeaf.getX())<=5&&Math.abs(nearestLog.getZ()-nearestLeaf.getZ())<=5&&nearestLeaf.getY()>=nearestLog.getY()-1&&nearestLeaf.getY()<=nearestLog.getY()+12;
   // A canopy can enter the scan before its trunk. Read a bounded, already-loaded
   // neighborhood around the nearest leaf; a wood tag near leaves is only evidence.
   boolean evidenceComplete=true;
   if(!tree&&nearestLeaf!=null){
    for(int x=nearestLeaf.getX()-5;x<=nearestLeaf.getX()+5;x++)for(int z=nearestLeaf.getZ()-5;z<=nearestLeaf.getZ()+5;z++){
     LevelChunk chunk=level.getChunkSource().getChunkNow(x>>4,z>>4);if(chunk==null){evidenceComplete=false;continue;}
     for(int y=Math.max(y0,nearestLeaf.getY()-12);y<=Math.min(y1,nearestLeaf.getY()+1);y++)if(chunk.getBlockState(new BlockPos(x,y,z)).is(BlockTags.LOGS))tree=true;
    }
   }
   number(n,"Tree evidence valid",evidenceComplete?1:0);number(n,"Sample tick",sp.getUniverseTime());number(n,"Valid",1);number(n,"Obstacle",Double.isFinite(best)?1:0);number(n,"Distance",Double.isFinite(best)?best:-1);number(n,"Lateral",Double.isFinite(best)?bestSide:0);number(n,"Possible tree",tree?1:0);text(n,"Kind",bestKind);text(n,"Block",bestBlock);text(n,"Status",Double.isFinite(best)?"BLOCK":"CLEAR");
  }
 }
}
