package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
local C=require('system.ascendancy.contracts')
local R=require('system.navigation.response_model')
local H=require('system.navigation.response_archive')
local ch={{id='vertical',backend='frequency',name='tx',link={first='a',second='b'},min=6,max=8,neutral=7,rescue=7,mix={}}}
local rows={}
for _,s in ipairs({-1,1}) do rows[#rows+1]={id='vertical',signal=7+s,response={0,0,s,0,0,0},noise={0,0,0,0,0,0},
 samples=8,baselineSamples=8,after=10,first=10.2,last=11,vehicleId='ship',singleCommand=true,otherOutputsChanged=false,
 clock='local_uptime',clockId='old-boot',frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2',
 excursion={0,0,2,0,0,0},maxRate={0,0,1,0,0,0},worldExcursion={0,0,2,0,0,0},worldMaxRate={0,0,1,0,0,0}} end
local provenance={vehicleId='ship',clock='local_uptime',clockId='old-boot',frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2'}
local snap={ok=true,inventoryComplete=true,vehicleId='ship',mass=65,units={mass='sable_mass',inertia='sable_mass*block^2'},inertia={{2,0,0},{0,3,0},{0,0,4}},centerOfMass={x=0,y=0,z=0}}
local report={schema=2,kind='known-output-characterization-not-flight-certificate',vehicleId='ship',qualification={state='complete'},binding=A.copy(ch),
 structureFingerprint=string.rep('a',64),mass=65,massUnit=snap.units.mass,inertia=A.copy(snap.inertia),inertiaUnit=snap.units.inertia,
 centerOfMass=A.copy(snap.centerOfMass),observationClockId='old-boot',model=assert(R.fit(ch,rows,provenance)),observations=rows,archivedAt=500}
local candidate=assert(H.candidate(report,ch,snap,report.structureFingerprint))
assert(candidate.model.axes.vertical.allocatable and candidate.model.provenance.clockId~=(C.clockId()),'archive made old derivatives current')
report.model.columns[1].response[3]=999
assert(H.candidate(report,ch,snap,report.structureFingerprint).model.columns[1].response[3]==1,'untrusted fitted coefficients reused instead of observations')
for _,fault in ipairs({'identity','structure','mass','unit','inertia','inertiaUnit','com','binding','clock','noise','incomplete','schema','cyclic'}) do
 local r,s,channels=A.copy(report),A.copy(snap),A.copy(ch)
 if fault=='identity' then s.vehicleId='other'
 elseif fault=='structure' then r.structureFingerprint=string.rep('b',64)
 elseif fault=='mass' then s.mass=70
 elseif fault=='unit' then s.units.mass='kg'
 elseif fault=='inertia' then s.inertia[1][1]=3
 elseif fault=='inertiaUnit' then s.units.inertia=nil
 elseif fault=='com' then s.centerOfMass.x=.2
 elseif fault=='binding' then channels[1].link.second='c'
 elseif fault=='clock' then r.observations[1].clockId='foreign'
 elseif fault=='noise' then r.observations[1].noise[3]=100
 elseif fault=='incomplete' then r.qualification.state='running'
 elseif fault=='schema' then r.schema=1
 elseif fault=='cyclic' then r.loop=r end
 local value=H.candidate(r,channels,s,report.structureFingerprint)
 assert(not value or not value.model.axes.vertical.allocatable,'invalid archive certified an axis: '..fault)
end
local a={channels=A.copy(ch),sensors={alt='nav'},balloonSetup={vehicleId='ship'},drivetrain={enabled=true,left={frequency='old'}}}
local b=A.copy(a) b.drivetrain.left.frequency='new'
assert(H.verticalBindingsEqual(a,b) and not H.motorBindingsEqual(a,b),'independent motor mapping invalidated vertical binding or reused old motors')
b.channels[1].link.second='changed'
assert(not H.verticalBindingsEqual(a,b),'burner binding change reused vertical model')
assert(a.drivetrain.left.frequency=='old','binding comparison mutated report')
print('Response archive: historical clocks preserved, raw evidence refitted, identity/structure/mass/inertia/COM/binding/provenance refusals, immutable candidates and independent vertical/motor bindings passed')

assert(not H.physicalChanged(snap,A.copy(snap)))
local altered=A.copy(snap) altered.inertia[1][1]=3 assert(H.physicalChanged(snap,altered)=='Observed inertia changed')
altered=A.copy(snap) altered.centerOfMass.y=.2 assert(H.physicalChanged(snap,altered)=='Observed center of mass changed')
altered=A.copy(snap) altered.inertia=nil assert(H.physicalChanged(snap,altered):find('availability',1,true))
local state=assert(loadfile('tests/storage-fixture.lua'))()()
local path='/system/config/navigation-response-v2.cfg'
state.config(path,report)
assert(H.load(path).observationClockId=='old-boot')
state.put(path..'.mintcraft-save/marker','MintCraft safe save 1')
state.config(path..'.mintcraft-save/previous',report) fs.delete(path)
assert(H.load(path).observationClockId=='old-boot' and not fs.exists(path..'.mintcraft-save'),'interrupted archive was not recovered before read')
state.put(path,string.rep('x',32769)) assert(not H.load(path),'oversized archive read without bound')
state.put(path,'not a table') assert(not H.load(path),'malformed archive accepted')
state.put(path,true) assert(not H.load(path),'directory archive accepted')
print('Archive storage: bounded reads, safe-save recovery and malformed/oversized/directory refusal passed')
