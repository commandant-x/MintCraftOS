package mintcraft.test;
import java.util.*;
/** Observer regressions: fresh sustained motion is different from a peak. */
public final class SpeedCriteriaTest {
 static SpeedCampaign.Frame f(long t,double vz,boolean locked,double ack,double protection,double scale){return new SpeedCampaign.Frame(t,0,170,t*.1,0,0,vz,5,0,170,1,protection,scale,ack,locked,111.5);}
 static boolean test(List<SpeedCampaign.Frame> frames){return SpeedCampaign.assess(frames,0,true,0,4,170,101);}
 static void require(boolean v,String s){if(!v)throw new AssertionError(s);}
 public static void main(String[] args){
  var frames=new ArrayList<SpeedCampaign.Frame>();for(int i=0;i<100;i++)frames.add(f(1000+i,4,false,101,0,1));require(test(frames),"steady fresh tracking rejected");
  var a=new ArrayList<>(frames);a.remove(0);require(!test(a),"short window passed");
  a=new ArrayList<>(frames);a.set(50,f(1049,4,false,101,0,1));require(!test(a),"duplicate clock passed");
  a=new ArrayList<>(frames);a.set(50,f(1051,4,false,101,0,1));require(!test(a),"gap passed");
  a=new ArrayList<>(frames);a.set(50,f(1050,4,true,101,0,1));require(!test(a),"locked sample passed");
  a=new ArrayList<>(frames);a.set(50,f(1050,4,false,100,0,1));require(!test(a),"unacknowledged command passed");
  a=new ArrayList<>(frames);a.set(50,f(1050,4,false,101,1,1));require(!test(a),"protection passed");
  a=new ArrayList<>(frames);a.set(50,f(1050,4,false,101,0,.5));require(!test(a),"reduced envelope passed as nominal");
  a=new ArrayList<>();for(int i=0;i<100;i++)a.add(f(1000+i,i==99?4:0,false,101,0,1));require(!test(a),"instant peak passed");
  a=new ArrayList<>();for(int i=0;i<100;i++)a.add(f(1000+i,3.5+i*.01,false,101,0,1));require(!test(a),"ongoing acceleration passed as terminal plateau");
  a=new ArrayList<>();for(int i=0;i<100;i++)a.add(f(1000+i,2,false,101,0,1));require(!test(a),"unreached speed passed as tracking");require(SpeedCampaign.assess(a,0,false,0,4,170,101),"physical plateau cannot be described separately");
  a=new ArrayList<>(frames);a.set(50,f(1050,Double.NaN,false,101,0,1));require(!test(a),"nonfinite velocity passed");
  var vertical=new ArrayList<SpeedCampaign.Frame>();for(int i=0;i<100;i++)vertical.add(new SpeedCampaign.Frame(1000+i,0,170,0,0,i<40?6:2,0,0,0,172,1,0,1,101,false,111.5));
  require(SpeedCampaign.assess(vertical,1,true,0,2,170,101),"valid final vertical window rejected");require(SpeedCampaign.recent(vertical,true).size()==60,"vertical report window length differs from criterion");require(SpeedCampaign.recent(vertical,true).stream().mapToDouble(SpeedCampaign.Frame::vy).average().orElseThrow()==2,"earlier vertical acceleration contaminates steady speed");
  System.out.println("Speed observer: sustained/fresh/acknowledged/unlocked tracking, peaks, gaps, adaptation and acceleration distinguished");
 }
}
