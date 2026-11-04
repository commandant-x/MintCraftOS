package mintcraft.test;

import java.nio.file.*;
import java.util.*;
import com.google.gson.GsonBuilder;
import net.minecraft.server.MinecraftServer;
import org.joml.Vector3d;
import org.joml.Quaterniond;
import dev.ryanhcode.sable.api.physics.handle.RigidBodyHandle;
import dev.simulated_team.simulated.content.physics_staff.PhysicsStaffServerHandler;

/** Observes actual native flight. Locks/teleports occur only in excluded resets. */
final class SpeedCampaign {
 enum Phase { BASELINE, CRUISE, BRAKE, RESET_OFF, RESET_LOCK, RESET_WARM, DONE }
 record Direction(String name,double angle,int vertical,int manual) {}
 record Frame(long tick,double x,double y,double z,double vx,double vy,double vz,double pitch,double roll,double target,double active,double protection,double scale,double ack,boolean locked,double mass) {
  double horizontal(){return Math.hypot(vx,vz);}double speed(){return Math.sqrt(vx*vx+vy*vy+vz*vz);}
  double tilt(){return Math.toDegrees(Math.acos(Math.max(-1,Math.min(1,Math.cos(Math.toRadians(pitch))*Math.cos(Math.toRadians(roll))))));}
 }
 final MintCraftFleetProbe p;final List<Direction> directions=new ArrayList<>();
 final ArrayDeque<Frame> window=new ArrayDeque<>();final List<Map<String,Object>> stages=new ArrayList<>(),results=new ArrayList<>();
 final Vector3d origin;final Quaterniond orientation;final double initialHeading,initialMass;final Path json;
 final double[] speeds={2,4,6,8,10,12,16,20,24,32,48,64};
 Phase phase=Phase.BASELINE;int directionIndex,goalIndex,revision=100,operationRevision=100,phaseStart,stableCount,stageId,refinements,noGain;
 double requested,nominalY,heading,failedUpper=Double.NaN,bestGoal,bestMean,peak,brakeDistance,brakeMinY;Frame last,brakeStart;
 boolean confirming,resetConfirmation;Map<String,Object> best,currentStable,confirmedBest;String endReason="";
 SpeedCampaign(MintCraftFleetProbe host)throws Exception{
  p=host;origin=new Vector3d(p.ship.logicalPose().position());orientation=new Quaterniond(p.ship.logicalPose().orientation());initialHeading=p.sp.getYaw();initialMass=p.sp.getShipMass();nominalY=p.sp.getY();phaseStart=p.ticks;
  String architecture=System.getProperty("mintcraft.fleet","tri");
  if(!architecture.equals("balloon-lift")){
   if(architecture.equals("quad-turns")||architecture.equals("quad-balanced")||architecture.equals("quad-banks")){directions.add(new Direction("forward",0,0,1));directions.add(new Direction("reverse",180,0,-1));}
   else for(var d:new Object[][]{{"forward",0d},{"reverse",180d},{"left",-90d},{"right",90d},{"forward_left",-45d},{"forward_right",45d},{"reverse_left",-135d},{"reverse_right",135d}})directions.add(new Direction((String)d[0],(double)d[1],0,0));
  }
  directions.add(new Direction("up",0,1,0));directions.add(new Direction("down",0,-1,0));
  String selected=System.getProperty("mintcraft.speedDirections","");if(!selected.isEmpty()){var names=Set.of(selected.split(","));directions.removeIf(d->!names.contains(d.name));}
  if(directions.isEmpty())throw new IllegalArgumentException("No supported selected speed direction");
  json=p.root.resolve("speed-results.json");
  Map<String,Object> contract=new LinkedHashMap<>();contract.put("architecture",architecture);contract.put("directions",directions);contract.put("heading_reference","fixed world vector relative to initial vehicle heading; no nose-heading guarantee");contract.put("horizontal_requests_m_s",speeds);contract.put("vertical_requests_m_s",new double[]{1,2,3,4,5});contract.put("configured_tilt_degrees",20);contract.put("horizontal_fresh_window_ticks",100);contract.put("vertical_fresh_window_ticks",60);contract.put("braking_fresh_window_ticks",100);contract.put("horizontal_altitude_error_m",1);contract.put("horizontal_vertical_speed_m_s",.15);contract.put("horizontal_cross_speed_m_s",.5);contract.put("vertical_cross_speed_m_s",.3);contract.put("tilt_span_degrees",3);contract.put("speed_span_m_s","max(0.25, 5% of measured mean)");contract.put("half_window_mean_change_m_s",.1);contract.put("tracking_tolerance_m_s","max(0.3, 15% of requested); required for vertical rate, separately reported for horizontal");contract.put("speed_phase_codes",Phase.values());contract.put("scope","measured limits of supplied craft and deployed controller; not a theoretical maximum");contract.put("reset","OFF, independent lock, native teleport/velocity reset, fresh controller arm; all reset frames excluded");write(p.root.resolve("speed-contract.json"),contract);
  // Vertical-only campaign starts at 1 m/s; rearm after configuring it.
  if(direction().vertical!=0){goalIndex=0;reset(false);}else beginBaseline();save();
 }
 Direction direction(){return directions.get(directionIndex);}
 double number(String name){return Double.parseDouble(p.output(p.controller,name));}
 Frame frame(){
  var v=p.sp.getVelocityVector();double scale=1;String report=p.output(p.controller,"Report");for(String line:report.split("\\n"))if(line.startsWith("MCF1,")){String[] a=line.split(",");if(a.length>=28)scale=Double.parseDouble(a[a.length-1]);}
  return new Frame(p.sp.getUniverseTime(),p.sp.getX(),p.sp.getY(),p.sp.getZ(),v.x,v.y,v.z,p.sp.getPitch(),p.sp.getRoll(),number("Target altitude"),number("Active"),Double.parseDouble(p.output(p.node("-operations"),"Stop horizontal")),scale,number("Acknowledged revision"),PhysicsStaffServerHandler.get(p.ship.getLevel()).isLocked(p.ship),p.sp.getShipMass());
 }
 void write(Path path,Object value)throws Exception{Files.writeString(path,new GsonBuilder().setPrettyPrinting().create().toJson(value));}
 void save()throws Exception{Map<String,Object> doc=new LinkedHashMap<>();doc.put("complete",phase==Phase.DONE);doc.put("directions",results);doc.put("stages",stages);doc.put("globally_qualified",false);write(json,doc);}
 void log(String message)throws Exception{p.event("SPEED "+direction().name+" "+message);}
 void phase(Phase next)throws Exception{phase=next;phaseStart=p.ticks;stableCount=0;window.clear();log("PHASE "+next+" goal="+requested);}
 void keys(int forward,int vertical)throws Exception{var f=p.fields(p.speedRadio);if(f.size()!=6)throw new IllegalStateException("Speed key transmitter not initialized");for(int i=0;i<6;i++)f.get(i).setValue("0");if(forward!=0)f.get(forward>0?0:1).setValue("15");if(vertical!=0)f.get(vertical>0?4:5).setValue("15");}
 void request(String mode,double speed)throws Exception{revision++;var f=p.fields(p.commands);f.get(f.size()-1).setValue("MCC1|"+revision+"|"+mode+"|"+nominalY+"|"+speed+"|"+heading+"||");}
 void beginBaseline()throws Exception{nominalY=p.sp.getY();heading=initialHeading+direction().angle;keys(0,0);request("HOLD",0);phase(Phase.BASELINE);}
 void startCruise()throws Exception{
  requested=direction().vertical!=0?goalIndex+1:direction().manual!=0?0:confirming?bestGoal:speeds[goalIndex];
  keys(direction().manual,direction().vertical);request(direction().vertical!=0||direction().manual!=0?"HOLD":"HEADING",requested);
  stageId++;peak=0;currentStable=null;phase(Phase.CRUISE);log("REQUEST requested="+requested+" revision="+revision+" confirmation="+confirming);
 }
 double along(Frame f){if(direction().vertical!=0)return f.vy*direction().vertical;double a=Math.toRadians(heading);return f.vx*Math.sin(a)+f.vz*Math.cos(a);}
 double cross(Frame f){if(direction().vertical!=0)return f.horizontal();double a=Math.toRadians(heading);return Math.abs(f.vx*Math.cos(a)-f.vz*Math.sin(a));}
 boolean cruiseStable(boolean tracking){return assess(new ArrayList<>(window),direction().vertical,tracking,heading,requested,nominalY,revision);}
 static List<Frame> recent(List<Frame> samples,boolean vertical){int n=vertical?60:100;return new ArrayList<>(samples.subList(Math.max(0,samples.size()-n),samples.size()));}
 static boolean assess(List<Frame> samples,int verticalSign,boolean tracking,double heading,double requested,double nominalY,int revision){
  boolean vertical=verticalSign!=0;double angle=Math.toRadians(heading);
  int n=vertical?60:100;if(samples.size()<n)return false;List<Frame> a=recent(samples,vertical);
  double low=Double.POSITIVE_INFINITY,high=-Double.MAX_VALUE,minTilt=90,maxTilt=0,first=0,second=0;
  for(int i=0;i<a.size();i++){Frame f=a.get(i);if(f.locked||f.active!=1||f.protection!=0||f.scale<.99||f.ack!=revision)return false;if(i>0&&f.tick!=a.get(i-1).tick+1)return false;
   if(f.tick<=0||f.mass<=0||!Double.isFinite(f.x+f.y+f.z+f.vx+f.vy+f.vz+f.pitch+f.roll+f.target+f.scale+f.ack+f.mass))return false;
   double v=vertical?f.vy*verticalSign:f.vx*Math.sin(angle)+f.vz*Math.cos(angle);double lateral=vertical?f.horizontal():Math.abs(f.vx*Math.cos(angle)-f.vz*Math.sin(angle));low=Math.min(low,v);high=Math.max(high,v);minTilt=Math.min(minTilt,f.tilt());maxTilt=Math.max(maxTilt,f.tilt());
   if(!vertical){if(Math.abs(f.y-nominalY)>1||Math.abs(f.vy)>.15||lateral>.5||f.tilt()>25)return false;}
   else if(lateral>.3||f.tilt()>5||Math.abs(f.target-f.y)>Math.max(2,requested*3))return false;
   if(tracking&&Math.abs(v-requested)>Math.max(.3,requested*.15))return false;
   if(i<n/2)first+=v;else second+=v;
  }
  double mean=(first+second)/n;return mean>.15&&maxTilt-minTilt<=3&&high-low<=Math.max(.25,.05*mean)&&Math.abs(second/(n-n/2)-first/(n/2))<=.1;
 }
 Map<String,Object> record(String status)throws Exception{
  var r=new LinkedHashMap<String,Object>();r.put("direction",direction().name);r.put("stage",stageId);r.put("status",status);r.put("requested_m_s",direction().manual!=0?null:requested);r.put("command_kind",direction().manual!=0?"manual_full":direction().vertical!=0?"vertical_keyboard":"heading_speed");r.put("confirmation",confirming);r.put("last_tick",p.ticks);r.put("peak_along_m_s",peak);
  List<Frame> samples=recent(new ArrayList<>(window),direction().vertical!=0);
  if(!samples.isEmpty()){double mean=0,min=Double.POSITIVE_INFINITY,max=-Double.MAX_VALUE,loY=Double.POSITIVE_INFINITY,hiY=-Double.MAX_VALUE;for(var f:samples){double v=along(f);mean+=v;min=Math.min(min,v);max=Math.max(max,v);loY=Math.min(loY,f.y);hiY=Math.max(hiY,f.y);}r.put("window_mean_m_s",mean/samples.size());r.put("window_min_m_s",min);r.put("window_max_m_s",max);r.put("altitude_min_m",loY);r.put("altitude_max_m",hiY);r.put("window_samples",samples.size());r.put("window_first_tick",p.ticks-samples.size()+1);r.put("window_last_tick",p.ticks);r.put("window_first_universe_tick",samples.get(0).tick);r.put("window_last_universe_tick",samples.get(samples.size()-1).tick);}
  stages.add(r);log("RESULT "+status+" mean="+r.get("window_mean_m_s"));save();return r;
 }
 void beginBrake()throws Exception{keys(0,0);request("HOLD",0);brakeStart=last;brakeDistance=0;brakeMinY=last.y;phase(Phase.BRAKE);}
 void failCruise(String why,boolean hard)throws Exception{
  record(why);endReason=why;
  if(direction().vertical!=0){finishVertical(false);return;}
  if(best!=null&&!confirming){
   if(!hard&&direction().manual==0&&requested-bestGoal>.5&&refinements++<3){failedUpper=requested;requested=(bestGoal+failedUpper)/2;keys(0,0);request("HEADING",requested);stageId++;peak=0;phase(Phase.CRUISE);return;}
   confirming=true;if(hard)reset(true);else startCruise();return;
  }
  finishDirection(false);
 }
 void markBrakeVerified(){
  if(currentStable==null)return;currentStable.put("braking_verified",true);currentStable.put("braking_duration_s",Math.max(0,(p.ticks-phaseStart-99)/20.));currentStable.put("braking_distance_m",brakeDistance);currentStable.put("braking_height_loss_m",Math.max(0,brakeStart.y-brakeMinY));
  if(confirmedBest==null||((Number)currentStable.get("window_mean_m_s")).doubleValue()>((Number)confirmedBest.get("window_mean_m_s")).doubleValue())confirmedBest=currentStable;
 }
 void finishVertical(boolean good)throws Exception{
  if(good)markBrakeVerified();
  if(goalIndex<4){goalIndex++;reset(false);}else finishDirection(confirmedBest!=null);
 }
 void finishDirection(boolean brakeGood)throws Exception{
  if(brakeGood&&direction().vertical==0)markBrakeVerified();
  Map<String,Object> r=new LinkedHashMap<>();r.put("direction",direction().name);r.put("last_stop_reason",endReason);r.put("highest_cruise_stable_stage",best);r.put("braking_verified",confirmedBest!=null);r.put("search_ceiling_reached",direction().manual==0&&direction().vertical==0&&goalIndex==speeds.length-1&&brakeGood);
  if(confirmedBest!=null){r.put("confirmed_speed_m_s",confirmedBest.get("window_mean_m_s"));r.put("confirmed_speed_km_h",((Number)confirmedBest.get("window_mean_m_s")).doubleValue()*3.6);r.put("command_m_s",confirmedBest.get("requested_m_s"));for(String k:new String[]{"braking_duration_s","braking_distance_m","braking_height_loss_m"})r.put(k,confirmedBest.get(k));}
  results.add(r);keys(0,0);log("DIRECTION_COMPLETE braking="+(confirmedBest!=null));save();
  if(directionIndex+1==directions.size()){phase=Phase.DONE;save();p.power(false);var staff=PhysicsStaffServerHandler.get(p.ship.getLevel());if(!staff.isLocked(p.ship))staff.toggleLock(p.ship.getUniqueId());Files.writeString(p.root.resolve("final-graph.snbt"),p.sp.graph.save().toString());return;}
  directionIndex++;goalIndex=0;bestGoal=0;bestMean=0;best=null;currentStable=null;confirmedBest=null;confirming=false;refinements=0;noGain=0;failedUpper=Double.NaN;endReason="";reset(false);
 }
 void reset(boolean confirmation)throws Exception{keys(0,0);p.power(false);var staff=PhysicsStaffServerHandler.get(p.ship.getLevel());if(!staff.isLocked(p.ship))staff.toggleLock(p.ship.getUniqueId());resetConfirmation=confirmation;phase(Phase.RESET_OFF);}
 void tick(MinecraftServer server)throws Exception{
  last=frame();
  if(phase==Phase.DONE){server.halt(false);return;}
  if(phase==Phase.RESET_OFF){if(p.ticks-phaseStart==20){var staff=PhysicsStaffServerHandler.get(p.ship.getLevel());if(staff.isLocked(p.ship))staff.removeLock(p.ship);var body=RigidBodyHandle.of(p.ship);body.addLinearAndAngularVelocity(new Vector3d(body.getLinearVelocity()).negate(),new Vector3d(body.getAngularVelocity()).negate());body.teleport(origin,orientation);p.fields(p.setup).get(1).setValue(direction().vertical!=0?Integer.toString(goalIndex+1):"5");p.fields(p.node("-operations")).get(3).setValue("MCREC1;"+(++operationRevision)+";CLEAR");}
   if(p.ticks-phaseStart>=30){var staff=PhysicsStaffServerHandler.get(p.ship.getLevel());if(!staff.isLocked(p.ship))staff.toggleLock(p.ship.getUniqueId());phase(Phase.RESET_LOCK);}return;}
  if(phase==Phase.RESET_LOCK){if(p.ticks-phaseStart>=30){p.power(true);phase(Phase.RESET_WARM);}return;}
  if(phase==Phase.RESET_WARM){
   boolean ready=last.active==1&&Math.abs(last.y-last.target)<1&&last.tilt()<5;
   if(p.burner!=null){ready=ready&&p.burner.getBalloon() instanceof dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon;if(ready){double supported=((dev.eriksonn.aeronautics.content.blocks.hot_air.balloon.ServerBalloon)p.burner.getBalloon()).getTotalLift()*p.gasPressure();ready=Math.abs(supported-p.ship.getMassTracker().getMass())<=p.ship.getMassTracker().getMass()*.05;}}
   if(ready)stableCount++;else stableCount=0;
   if(stableCount>=40&&p.ticks-phaseStart>=100){var staff=PhysicsStaffServerHandler.get(p.ship.getLevel());staff.removeLock(p.ship);confirming=resetConfirmation;beginBaseline();}
   else if(p.ticks-phaseStart>800){record("RESET_REARM_FAILED");finishDirection(false);}return;
  }
  if(last.tick<=0||last.active!=1||last.locked||last.y<80||last.y>285||Math.abs(last.x-origin.x)>8192||Math.abs(last.z-origin.z)>8192||last.tilt()>35||last.protection!=0||Math.abs(last.mass-initialMass)>initialMass*.0001){
   if(phase==Phase.CRUISE)failCruise("FLIGHT_ENVELOPE_OR_CONTROLLER_FAULT",true);else{endReason="BASELINE_OR_BRAKING_FAULT";if(direction().vertical!=0)finishVertical(false);else finishDirection(false);}return;
  }
  window.add(last);while(window.size()>100)window.removeFirst();
  if(phase==Phase.BASELINE){
   if(last.speed()<=.2&&Math.abs(last.y-last.target)<=1&&last.tilt()<=5)stableCount++;else stableCount=0;
   if(stableCount>=40){nominalY=last.y;startCruise();}else if(p.ticks-phaseStart>600){endReason="BASELINE_NOT_STABLE";finishDirection(false);}return;
  }
  if(phase==Phase.CRUISE){
   peak=Math.max(peak,along(last));int age=p.ticks-phaseStart;
   boolean stable=cruiseStable(direction().vertical!=0);
   if(stable&&age>=(direction().vertical!=0?160:120)){
    Map<String,Object> candidate=record("CRUISE_STABLE");currentStable=candidate;double mean=((Number)candidate.get("window_mean_m_s")).doubleValue();
    candidate.put("tracking_verified",cruiseStable(true));if(best!=null&&mean<=bestMean+.2)noGain++;else noGain=0;
    if(best==null||mean>bestMean){best=candidate;bestMean=mean;bestGoal=requested;}
    if(direction().vertical!=0||direction().manual!=0||confirming){beginBrake();return;}
    if(noGain>=2){endReason="COMMAND_INCREASE_NO_SPEED_GAIN";beginBrake();return;}
    if(Double.isFinite(failedUpper)){if(failedUpper-requested>.5&&refinements++<3){requested=(requested+failedUpper)/2;keys(0,0);request("HEADING",requested);stageId++;peak=0;phase(Phase.CRUISE);}else beginBrake();return;}
    if(goalIndex+1<speeds.length){goalIndex++;startCruise();}else beginBrake();return;
   }
   if(age>=(direction().vertical!=0?240:direction().manual!=0?600:400)){
    if(last.ack!=revision)failCruise("COMMAND_NOT_ACKNOWLEDGED",false);else failCruise(cruiseStable(false)?"STABLE_BUT_SPEED_UNREACHED":"CRUISE_NOT_STABLE",false);
   }return;
  }
  if(phase==Phase.BRAKE){
   brakeDistance=Math.max(brakeDistance,Math.hypot(last.x-brakeStart.x,last.z-brakeStart.z));brakeMinY=Math.min(brakeMinY,last.y);
   if(last.speed()<=.2&&Math.abs(last.y-last.target)<=1&&last.tilt()<=5&&last.scale>=.99)stableCount++;else stableCount=0;
   if(stableCount>=100){if(direction().vertical!=0)finishVertical(true);else finishDirection(true);}
   else if(p.ticks-phaseStart>=800){endReason="BRAKING_NOT_STABLE";if(direction().vertical!=0)finishVertical(false);else finishDirection(false);}
  }
 }
 String csv(){return ","+directionIndex+","+phase.ordinal()+","+requested+","+stageId+","+(last!=null&&last.locked?1:0)+","+(last!=null?last.mass:p.sp.getShipMass());}
}
