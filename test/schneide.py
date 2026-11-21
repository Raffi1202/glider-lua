# Schneidet die Widget-Fläche (x 8, y 90, Breite x Höhe aus dem Dateinamen) aus einem 800x480-Simulatorbild aus.
# Aufruf nach den Abläufen 40–42: python3 test/schneide.py docs/bilder-simulator test/stand-bilder/roh-*.png
import sys,zlib,struct,re,os
def lies(p):
    d=open(p,'rb').read();o=8;idat=[]
    while o<len(d):
        l=struct.unpack('>I',d[o:o+4])[0];k=d[o+4:o+8];c=d[o+8:o+8+l]
        if k==b'IHDR':W,H,bd,ct=struct.unpack('>IIBB',c[:10])
        if k==b'IDAT':idat.append(c)
        o+=12+l
    bpp=3 if ct==2 else 4;z=W*bpp;r=zlib.decompress(b''.join(idat));px=bytearray(H*z)
    for y in range(H):
        f=r[y*(z+1)];q=r[y*(z+1)+1:(y+1)*(z+1)]
        for x in range(z):
            a=px[y*z+x-bpp] if x>=bpp else 0;b=px[(y-1)*z+x] if y else 0;c=px[(y-1)*z+x-bpp] if (y and x>=bpp) else 0;v=q[x]
            if f==1:v+=a
            elif f==2:v+=b
            elif f==3:v+=(a+b)>>1
            elif f==4:
                pp=a+b-c;pa,pb,pc=abs(pp-a),abs(pp-b),abs(pp-c);v+=a if pa<=pb and pa<=pc else (b if pb<=pc else c)
            px[y*z+x]=v&255
    return W,H,bpp,px
def schreib(p,b,h,rows):
    def st(k,c):return struct.pack('>I',len(c))+k+c+struct.pack('>I',zlib.crc32(k+c)&0xffffffff)
    raw=b''.join(b'\0'+r for r in rows)
    open(p,'wb').write(b'\x89PNG\r\n\x1a\n'+st(b'IHDR',struct.pack('>IIBBBBB',b,h,8,2,0,0,0))+st(b'IDAT',zlib.compress(raw,9))+st(b'IEND',b''))
for roh in sys.argv[2:]:
    name=os.path.basename(roh)[4:];b,h=map(int,re.search(r'(\d+)x(\d+)',name).groups())
    W,H,bpp,px=lies(roh);rows=[]
    for y in range(90,90+h):
        rows.append(bytes(px[y*W*bpp+x*bpp+i] for x in range(8,8+b) for i in range(3)))
    schreib(os.path.join(sys.argv[1],name),b,h,rows);print('geschnitten',name)
