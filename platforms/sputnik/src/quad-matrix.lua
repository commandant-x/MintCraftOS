-- The dedicated quad accepts only four vertical force actuators.
-- This preserves the general model for accepted groups, without dead surface paths.
function M.matrix(groups,pose,velocity,baseMass,directions)
 local columns,meta={},{};local mass=pose.mass
 local up=M.world({x=0,y=1,z=0},pose.q)
 for i,g in ipairs(groups) do
  if (g.kind~='bearing' and g.kind~='small') or g.role~='lift' or g.dx~=0 or g.dy~=1 or g.dz~=0 then return nil,'FPV: helices verticales requises' end
  local sign=directions and directions[g.id] or 1
  local height=pose.y+M.world({x=g.x,y=g.y,z=g.z},pose.q).y
  local pressure=Physics.pressure(height);if not pressure or pressure<=0 then return nil,'Atmosphere indisponible' end
  local axial=sign*((velocity.x or 0)*up.x+(velocity.y or 0)*up.y+(velocity.z or 0)*up.z)
  local thrust,flow,alpha=M.coefficients(g)
  local unit=Physics.force(g.source,pressure,axial,thrust,flow)*g.members/15
  columns[i]={id=tostring(g.id),response={0,0,sign*unit/mass,-g.z*sign*unit/pose.ix,0,g.x*sign*unit/pose.iz},low=0,high=15,neutral=0}
  meta[i]={group=g,unit=unit,pressure=pressure,axial=axial,thrust=thrust,airflow=flow,alpha=alpha}
 end
 return {columns=columns,scale={1,1,1,.1,.1,.1}},meta,{0,0,0,0,0,0},up
end
