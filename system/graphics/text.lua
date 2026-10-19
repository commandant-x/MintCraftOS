-- Convert display strings to the embedded CP437 font, never alter stored text.
local M={limit=65536}
local latin={
  [0x00c7]=128,[0x00fc]=129,[0x00e9]=130,[0x00e2]=131,[0x00e4]=132,[0x00e0]=133,
  [0x00e5]=134,[0x00e7]=135,[0x00ea]=136,[0x00eb]=137,[0x00e8]=138,[0x00ef]=139,
  [0x00ee]=140,[0x00ec]=141,[0x00c4]=142,[0x00c5]=143,[0x00c9]=144,[0x00e6]=145,
  [0x00c6]=146,[0x00f4]=147,[0x00f6]=148,[0x00f2]=149,[0x00fb]=150,[0x00f9]=151,
  [0x00ff]=152,[0x00d6]=153,[0x00dc]=154,[0x00a2]=155,[0x00a3]=156,[0x00a5]=157,
  [0x00e1]=160,[0x00ed]=161,[0x00f3]=162,[0x00fa]=163,[0x00f1]=164,[0x00d1]=165,
  [0x00aa]=166,[0x00ba]=167,[0x00bf]=168,[0x00ac]=170,[0x00bd]=171,[0x00bc]=172,
  [0x00a1]=173,[0x00ab]=174,[0x00bb]=175,[0x00df]=225,[0x00b5]=230,[0x00b0]=248,
  [0x00b7]=250,[0x00b2]=253,[0x00a0]=255,
}
local substitutes={[0x0153]="oe",[0x0152]="OE",[0x2018]="'",[0x2019]="'",
  [0x201c]='"',[0x201d]='"',[0x2013]="-",[0x2014]="-",[0x2026]="..."}
local combining={
  [0x0300]={[97]=133,[101]=138,[105]=141,[111]=149,[117]=151},
  [0x0301]={[97]=160,[101]=130,[105]=161,[111]=162,[117]=163,[69]=144},
  [0x0302]={[97]=131,[101]=136,[105]=140,[111]=147,[117]=150},
  [0x0308]={[97]=132,[101]=137,[105]=139,[111]=148,[117]=129,[121]=152,[65]=142,[79]=153,[85]=154},
  [0x0327]={[99]=135,[67]=128},
}
local function nextCode(s,i)
  local a,b,c,d=s:byte(i,i+3)
  if a<128 then return a,i+1 end
  local n=a>=194 and a<=223 and 2 or a>=224 and a<=239 and 3 or a>=240 and a<=244 and 4
  if not n then return nil,i+1 end
  if not b or b<128 or b>191 then return nil,i+1 end
  if n>=3 and (not c or c<128 or c>191 or a==224 and b<160 or a==237 and b>159) then return nil,i+1 end
  if n==4 and (not d or d<128 or d>191 or a==240 and b<144 or a==244 and b>143) then return nil,i+1 end
  local cp=n==2 and (a-192)*64+b-128 or n==3 and (a-224)*4096+(b-128)*64+c-128
    or (a-240)*262144+(b-128)*4096+(c-128)*64+d-128
  return cp,i+n
end
function M.decode(value,encoding)
  local s=tostring(value or "")
  encoding=encoding or "cp437"
  assert(encoding=="cp437" or encoding=="utf8" or encoding=="auto","Invalid text encoding")
  local clipped=#s>M.limit
  s=s:sub(1,M.limit)
  if encoding=="auto" then
    local i,valid=1,true
    while i<=#s do local cp,j=nextCode(s,i) if not cp then valid=false break end i=j end
    encoding=valid and "utf8" or "cp437"
  end
  if encoding=="cp437" then return s,clipped end
  local out,i={},1
  while i<=#s do
    local cp,j=nextCode(s,i)
    if cp and combining[cp] and #out>0 and #out[#out]==1 and combining[cp][out[#out]:byte()] then
      out[#out]=string.char(combining[cp][out[#out]:byte()])
    else
      local mapped=cp and (cp<128 and string.char(cp) or latin[cp] and string.char(latin[cp]) or substitutes[cp])
      out[#out+1]=mapped or "?"
    end
    i=j
  end
  return table.concat(out),clipped
end
function M.single(value,encoding)
  return (M.decode(value,encoding or "auto"):gsub("[%c]"," "))
end
return M
