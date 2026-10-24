import java.lang.reflect.*;
public final class VerifySablePressure {
 public static void main(String[] args) throws Exception {
  Class<?> type=Class.forName("dev.ryanhcode.sable.physics.config.dimension_physics.BezierResourceFunction");
  Class<?> point=Class.forName(type.getName()+"$BezierPoint");
  Object curve=type.getConstructor().newInstance();
  Constructor<?> ctor=point.getConstructor(double.class,double.class,double.class);
  Method add=type.getMethod("addPoint",point),evaluate=type.getMethod("evaluateFunction",double.class);
  double sea=63,top=320,current=Math.max(-64,Math.log(1.5)/-.004+sea),last=0;
  for(int i=0;i<16;i++) {
   double p=Math.exp(-.004*(current-sea));add.invoke(curve,ctor.newInstance(current,p,-.004*p));last=p;
   if(current>=280)break;
   if(current<sea&&current+200>=sea)current=sea;
   else if(current<280&&current+200>=280)current=280;
   else current+=200;
  }
  add.invoke(curve,ctor.newInstance(top,0.,-2*last/40));
  for(int y=-80;y<=340;y++) System.out.println(y+","+evaluate.invoke(curve,(double)y));
 }
}
