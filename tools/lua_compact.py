"""Conservative Lua token whitespace compaction; keep source lines for host pin scan."""
import re
_WORD=re.compile(r'[A-Za-z_][A-Za-z_0-9]*')
_NUMBER=re.compile(r'(?:0[xX][0-9a-fA-F]+(?:\.(?!\.)[0-9a-fA-F]*)?(?:[pP][+-]?\d+)?|(?:\d+\.(?!\.)\d*|\d+|\.\d+)(?:[eE][+-]?\d+)?)')
_MULTI={'...','..','==','~=','<=','>=','::','//','<<','>>'}
def compact(text, identifiers=None, keep_lines=True, private_identifiers=False, explicit_methods=False):
    pin_lines={i for i,value in enumerate(text.splitlines(),1) if re.search(r'\b(?:input|output)\s*\(',value)}
    tokens=[];i=0;line=False;row=1
    while i<len(text):
        c=text[i]
        if c.isspace():
            line=line or c=='\n';row+=c=='\n';i+=1;continue
        if text.startswith('--',i):
            long=re.match(r'--\[(=*)\[',text[i:])
            if long:
                end=text.find(']'+long[1]+']',i+len(long[0]))
                if end<0: raise ValueError('Unterminated Lua comment')
                line=line or '\n' in text[i:end];row+=text[i:end].count('\n');i=end+len(long[1])+2
            else:
                end=text.find('\n',i);i=len(text) if end<0 else end;line=True
            continue
        start=i;start_row=row
        if c in "'\"":
            quote=c;i+=1
            while i<len(text):
                if text[i]=='\\': i+=2
                elif text[i]==quote: i+=1;break
                else: i+=1
            else: raise ValueError('Unterminated Lua string')
        elif c=='[' and (long:=re.match(r'\[(=*)\[',text[i:])):
            end=text.find(']'+long[1]+']',i+len(long[0]))
            if end<0: raise ValueError('Unterminated long Lua string')
            i=end+len(long[1])+2
        elif (m:=_WORD.match(text,i)) or (m:=_NUMBER.match(text,i)):
            i=m.end()
        else:
            op=next((v for v in ('...','..','==','~=','<=','>=','::','//','<<','>>') if text.startswith(v,i)),None)
            i+=len(op) if op else 1
        token=text[start:i]
        tokens.append((token,line,start_row));row+=text[start:i].count('\n');line=False
    if explicit_methods:
        # Lua's colon definition is exactly a dot definition with a first self
        # argument. Make that implicit local explicit before shortening locals.
        i=0
        while i<len(tokens):
            if tokens[i][0]=='function':
                j=i+1
                while j<len(tokens) and (_WORD.fullmatch(tokens[j][0]) or tokens[j][0]=='.'): j+=1
                if j+2<len(tokens) and tokens[j][0]==':' and _WORD.fullmatch(tokens[j+1][0]) and tokens[j+2][0]=='(':
                    value,newline,row=tokens[j];tokens[j]=('.',newline,row)
                    extra=[('self',False,row)]
                    if tokens[j+3][0]!=')': extra.append((',',False,row))
                    tokens[j+3:j+3]=extra
            i+=1
    identifiers=dict(identifiers or {})
    explicit=set(identifiers)
    field_positions=set()
    for i,(value,_,_) in enumerate(tokens):
        previous=tokens[i-1][0] if i else ''
        following=tokens[i+1][0] if i+1<len(tokens) else ''
        if previous in ('.',':') or previous in ('{',',',';') and following=='=': field_positions.add(i)
    if private_identifiers:
        # Only the audited native bundle opts in: never rename any field, literal
        # key, keyword or host/global API. Renaming is global across local scopes.
        reserved=set(('and break do else elseif end false for function goto if in local nil not or repeat return then true until while '
          'self _G _ENV _VERSION assert collectgarbage dofile error getmetatable ipairs load loadfile next pairs pcall print rawequal rawget rawlen rawset select setmetatable tonumber tostring type xpcall '
          'math table string bit32 coroutine debug os io package require unpack input output ui addElement removeElement display transmitWirelessRedstone receiveWirelessRedstone').split())
        if explicit_methods: reserved.discard('self')
        words={value for value,_,_ in tokens if _WORD.fullmatch(value)}
        for i,(value,_,_) in enumerate(tokens):
            previous=tokens[i-1][0] if i else ''
            following=tokens[i+1][0] if i+1<len(tokens) else ''
            if len(value)>1 and value[0] in "'\"" and _WORD.fullmatch(value[1:-1]): reserved.add(value[1:-1])
        for index in field_positions:
            if tokens[index-1][0] not in ('.',':'): reserved.add(tokens[index][0])
        counts={word:sum(value==word for value,_,_ in tokens) for word in words if len(word)>=3 and word not in reserved and word not in identifiers}
        for i,word in enumerate(sorted(counts,key=lambda x:(counts[x]*(len(x)-2),x),reverse=True)):
            digits='abcdefghijklmnopqrstuvwxyz'
            value=i;alias=''
            while True:
                alias=digits[value%26]+alias;value=value//26-1
                if value<0: break
            alias='_'+alias
            if alias not in words and len(alias)<len(word): identifiers[word]=alias
    out=[];previous='';previous_row=0
    for index,(token,newline,token_row) in enumerate(tokens):
        if (index not in field_positions or token in explicit) and _WORD.fullmatch(token): token=identifiers.get(token,token)
        if previous:
            word=(previous[-1].isalnum() or previous[-1]=='_') and (token[0].isalnum() or token[0]=='_')
            ambiguity=previous+token in _MULTI or previous.endswith('-') and token.startswith('-') or bool(_NUMBER.fullmatch(previous)) and token.startswith('.')
            if newline and (keep_lines or token_row in pin_lines or previous_row in pin_lines): out.append('\n')
            elif word or ambiguity: out.append(' ')
        out.append(token);previous=token;previous_row=token_row
    return ''.join(out)+'\n'
