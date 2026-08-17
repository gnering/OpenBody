using System; using System.IO; using System.Reflection; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.Globalization; using System.Threading;
class T {
  static string dir; static Type bt; static object inst; static bool isEn=false;
  static Assembly Resolve(object s, ResolveEventArgs a){
    var an=new AssemblyName(a.Name); var n=an.Name;
    if(n.EndsWith(".resources")){
      // Inglês = idioma-base embutido nas próprias DLLs (nenhum satélite): não carrega o pt-BR.
      var cult=(an.CultureInfo!=null && an.CultureInfo.Name.Length>0)?an.CultureInfo.Name:"";
      if(cult.Length>0){ var pc=Path.Combine(dir,cult,n+".dll"); if(File.Exists(pc)) return Assembly.LoadFrom(pc); }
      if(!isEn){ var pb=Path.Combine(dir,"pt-BR",n+".dll"); if(File.Exists(pb)) return Assembly.LoadFrom(pb); }
      return null;
    }
    var p=Path.Combine(dir,n+".dll"); return File.Exists(p)?Assembly.LoadFrom(p):null;
  }
  static void setp(string n, object v){ var pi=bt.GetProperty(n); if(pi!=null&&pi.CanWrite){ try{ pi.SetValue(inst,v); }catch(Exception e){ Console.WriteLine("  warn setp "+n+": "+e.Message); } } else Console.WriteLine("  warn: no base prop "+n); }
  static void setTbl(string sec, string field, string val){
    var pi=bt.GetProperty("Cls"+sec+"_TBL"); if(pi==null){ Console.WriteLine("  warn: no TBL Cls"+sec+"_TBL"); return; }
    var obj=pi.GetValue(inst); var fp=obj.GetType().GetProperty(field);
    if(fp==null){ Console.WriteLine("  warn: no field "+sec+"."+field); return; }
    try{ fp.SetValue(obj,val); }catch(Exception e){ Console.WriteLine("  warn set "+sec+"."+field+": "+e.Message); }
  }
  // find non-white bounding box and paste it centered on a fresh white A4 bitmap
  static Bitmap CenterContent(Bitmap src){
    int W=src.Width, H=src.Height, minX=W, minY=H, maxX=-1, maxY=-1;
    var rect=new Rectangle(0,0,W,H);
    var bd=src.LockBits(rect,System.Drawing.Imaging.ImageLockMode.ReadOnly,System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    int stride=bd.Stride; var buf=new byte[stride*H];
    System.Runtime.InteropServices.Marshal.Copy(bd.Scan0,buf,0,buf.Length); src.UnlockBits(bd);
    for(int y=0;y<H;y++){ int row=y*stride; for(int x=0;x<W;x++){ int i=row+x*4;
      // BGRA; treat near-white as background
      if(buf[i]<248||buf[i+1]<248||buf[i+2]<248){ if(x<minX)minX=x; if(x>maxX)maxX=x; if(y<minY)minY=y; if(y>maxY)maxY=y; } } }
    if(maxX<0) return src;
    int cw=maxX-minX+1, ch=maxY-minY+1;
    // saída A4 fixa 2480x3508; conteúdo recortado e centralizado (nada corta)
    int OW=2480, OH=3508;
    var outb=new Bitmap(OW,OH); outb.SetResolution(300,300);
    using(var g=Graphics.FromImage(outb)){ g.Clear(Color.White);
      int ox=(OW-cw)/2, oy=(OH-ch)/2; if(ox<0)ox=0; if(oy<0)oy=0;
      g.DrawImage(src,new Rectangle(ox,oy,cw,ch),new Rectangle(minX,minY,cw,ch),GraphicsUnit.Pixel); }
    return outb;
  }
  // args: dir dll type out datafile [culture]   culture = "pt-BR" (padrão) ou "en-US"
  static void Main(string[] args){
    dir=args[0]; string dll=args[1], typeName=args[2], outPng=args[3], data=args[4];
    string culture=args.Length>5 ? args[5] : "pt-BR";
    string unit=args.Length>6 ? args[6] : "0";          // "0" métrico (kg/cm), "1" imperial (lb/in)
    bool imperial = unit=="1";
    isEn = culture.StartsWith("en");
    // O motor parseia números com a CurrentCulture e monta os literais de escala com o NumberFormat.
    // pt-BR = vírgula (como o LookinBody no Brasil); en-US = ponto (idioma-base das DLLs).
    try{ var ci=new CultureInfo(isEn?"en-US":"pt-BR"); Thread.CurrentThread.CurrentUICulture=ci; Thread.CurrentThread.CurrentCulture=ci; }catch{}
    AppDomain.CurrentDomain.AssemblyResolve += Resolve;
    try {
      var asm=Assembly.LoadFrom(Path.Combine(dir,dll));
      var t=asm.GetType(typeName); inst=Activator.CreateInstance(t); bt=t.BaseType;
      setp("Paper","A4"); setp("Left",30f); setp("Top",25f);
      setp("Language",isEn?"EN":"BR"); setp("CountryCode",isEn?"1":"55");
      setp("NumberFormat",isEn?".":","); setp("DateFormat",isEn?"yyyy.MM.dd.":"dd.MM.yyyy."); setp("TimeFormat","HH:mm"); setp("UsePrintedPaper",false);
      // UnitMass is the unit for TOTAL BODY WATER (liters); UnitWeight is kg for mass rows.
      if(imperial){ setp("Unit","1"); setp("UnitMass","lb"); setp("UnitWeight","lb"); setp("UnitPercent","%"); setp("UnitLength","in"); }
      else       { setp("Unit","0"); setp("UnitMass","L");  setp("UnitWeight","kg"); setp("UnitPercent","%"); setp("UnitLength","cm"); }
      // NOTE: do NOT overwrite Font/StringFormat props — base ctor's InitializeControl() already
      // sets them to the real InBody sizes/alignments (score 20pt, unit 7pt, SfCF center, SfFF right...).
      // Only ensure the data-table objects exist (instantiate if base left them null).
      foreach(var pi in bt.GetProperties(BindingFlags.Public|BindingFlags.Instance)){
        if(!pi.CanWrite) continue;
        if(pi.PropertyType.Name.EndsWith("_TBL")||pi.PropertyType.Name=="BloodPressureData"||pi.PropertyType.Name=="InBodyDialysis"){
          try{ if(pi.GetValue(inst)==null) pi.SetValue(inst,Activator.CreateInstance(pi.PropertyType)); }catch{}
        }
      }
      // load data
      foreach(var raw in File.ReadAllLines(data)){
        var line=raw.Trim(); if(line.Length==0||line[0]=='#') continue;
        int eq=line.IndexOf('='); if(eq<0) continue;
        string k=line.Substring(0,eq).Trim(), v=line.Substring(eq+1).Trim();
        if(k=="RIGHT"){ setp("ResultsSheetRightOption",v); continue; }
        // logo da clinica no canto direito do cabecalho (o header ajusta ao quadro 265x90).
        // Moldura transparente de 15% em volta -> o logo sai 15% menor, ainda centralizado.
        if(k=="LOGO"){ try{
          var li=Image.FromFile(v);
          int pw=(int)(li.Width/0.85f), ph=(int)(li.Height/0.85f);
          var pad=new Bitmap(pw,ph);
          using(var pg=Graphics.FromImage(pad)){
            pg.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            pg.DrawImage(li,(pw-li.Width)/2,(ph-li.Height)/2,li.Width,li.Height); }
          setp("Logo",(Image)pad);
        }catch(Exception le){ Console.WriteLine("  warn logo: "+le.Message); } continue; }
        if(k=="EQUIP"){ setp("Equip",v); setTbl("BCA","EQUIP",v); continue; }
        if(k.StartsWith("STR.")){ setp(k.Substring(4),v); continue; }
        if(k.StartsWith("INT.")){ setp(k.Substring(4),int.Parse(v)); continue; }
        if(k.StartsWith("FLT.")){ setp(k.Substring(4),float.Parse(v,CultureInfo.InvariantCulture)); continue; }
        if(k.StartsWith("BOOL.")){ setp(k.Substring(5),bool.Parse(v)); continue; }
        if(k.StartsWith("ARR.")){ setp("Arr"+k.Substring(4), v.Split('|')); continue; }
        int d=k.IndexOf('.'); if(d<0) continue;
        setTbl(k.Substring(0,d), k.Substring(d+1), v);
      }
      // placeholder QR so r_qr block doesn't NRE
      var qpi=bt.GetProperty("QRCode");
      if(qpi!=null && qpi.GetValue(inst)==null){
        var q=new Bitmap(90,90); using(var qg=Graphics.FromImage(q)){ qg.Clear(Color.White); var rnd=new Random(7);
          for(int yy=0;yy<30;yy++) for(int xx=0;xx<30;xx++){ if(rnd.Next(2)==0) qg.FillRectangle(Brushes.Black, xx*3, yy*3, 3, 3); } }
        try{ qpi.SetValue(inst,q); }catch{}
      }
      // canvas MAIOR que o A4 pra o deslocamento (Left+30/Top+15) não cortar nada; CenterContent recorta no A4.
      var bmp=new Bitmap(2620,3660); bmp.SetResolution(300,300); var g=Graphics.FromImage(bmp); g.Clear(Color.White);
      g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
      g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
      g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
      g.ScaleTransform(3f,3f);
      try{ t.GetMethod("DrawResultsSheet").Invoke(inst,new object[]{g}); }
      catch(Exception ex2){ var ie=ex2.InnerException??ex2; Console.WriteLine("PARCIAL: "+ie.GetType().Name+": "+ie.Message); Console.WriteLine(ie.StackTrace); }
      g.Dispose();
      // center content on the A4 canvas (equal margins) — find non-white bbox and recenter
      var centered=CenterContent(bmp);
      centered.Save(outPng,ImageFormat.Png);
      Console.WriteLine("RENDER OK -> "+outPng);
    } catch(Exception e){ var ex=e.InnerException??e; Console.WriteLine("FAIL: "+ex.GetType().Name+": "+ex.Message); Console.WriteLine(ex.StackTrace); }
  }
}
