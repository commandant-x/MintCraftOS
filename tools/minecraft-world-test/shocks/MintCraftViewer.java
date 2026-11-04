package mintcraft.test;
import net.neoforged.fml.common.Mod;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.client.event.ClientTickEvent;
import net.minecraft.client.Minecraft;
import net.minecraft.client.Screenshot;
import net.minecraft.client.gui.screens.*;
import net.minecraft.client.gui.screens.multiplayer.JoinMultiplayerScreen;
import net.minecraft.client.multiplayer.ServerData;
import net.minecraft.client.multiplayer.resolver.ServerAddress;
import java.nio.file.*;
@Mod(value="mintcraft_viewer",dist=Dist.CLIENT)
public class MintCraftViewer {
 private int ticks,lastAttempt=-1000,frames;
 public MintCraftViewer(){NeoForge.EVENT_BUS.addListener(this::tick);}
 private void tick(ClientTickEvent.Post event){
  Minecraft mc=Minecraft.getInstance();ticks++;
  if(mc.level==null && mc.getOverlay()==null && ticks-lastAttempt>=200 && (mc.screen instanceof TitleScreen || mc.screen instanceof DisconnectedScreen || mc.screen instanceof JoinMultiplayerScreen)){
   lastAttempt=ticks;String localWorld=System.getProperty("mintcraft.viewerWorld");try{Path selection=mc.gameDirectory.toPath().resolve("viewer-world.txt");if(Files.exists(selection))localWorld=Files.readString(selection).strip();}catch(Exception ignored){}if(localWorld!=null&&!localWorld.isBlank()){mc.createWorldOpenFlows().openWorld(localWorld,()->{});return;}ConnectScreen.startConnecting(new TitleScreen(),mc,ServerAddress.parseString("127.0.0.1:25585"),new ServerData("MintCraft isolated test","127.0.0.1:25585",ServerData.Type.OTHER),false,null);
  }
  if(mc.level!=null && mc.player!=null && ticks%40==0 && frames<600){
   String name="observer-"+System.currentTimeMillis()+".png";Screenshot.grab(mc.gameDirectory,name,mc.getMainRenderTarget(),message->{});frames++;
   try{Files.writeString(mc.gameDirectory.toPath().resolve("viewer-ready.txt"),System.currentTimeMillis()+"\n");}catch(Exception ignored){}
  }
 }
}
