import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AnaMuslimApp());
}

class AnaMuslimApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أنا مسلم',
      theme: ThemeData(fontFamily: 'Cairo', primarySwatch: Colors.green),
      home: AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasData) return MainScreen();
        return Scaffold(
          body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("أنا مسلم 🕌", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () async { await FirebaseAuth.instance.signInAnonymously(); }, child: Text("دخول للبرنامج"))
          ])),
        );
      },
    );
  }
}

class AppService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  Future<String> createHalaqa(String masjid, String teacher) async {
    var check = await db.collection('halaqat').where('teacherId', isEqualTo: auth.currentUser!.uid).get();
    if (check.docs.isNotEmpty) return "عندك حلقة وحدة بس";
    await db.collection('halaqat').add({'halaqaName': "حلقة $masjid - $teacher", 'masjidName': masjid, 'teacherName': teacher, 'teacherId': auth.currentUser!.uid, 'createdAt': FieldValue.serverTimestamp()});
    return "تم انشاء الحلقة ✅";
  }
  Future<String> giveStar(String halaqaId, String studentId) async {
    String uid = auth.currentUser!.uid;
    var t = await db.collection('users').doc(uid).get();
    int bal = t.data()?['starsBalance'] ?? 50;
    if (bal <= 0) return "رصيدك خلص ❌";
    await db.collection('users').doc(uid).set({'starsBalance': bal - 1}, SetOptions(merge: true));
    var sRef = db.collection('halaqat').doc(halaqaId).collection('stars').doc(studentId);
    var s = await sRef.get();
    if (!s.exists) await sRef.set({'count': 1}); else await sRef.update({'count': s.data()!['count'] + 1});
    var stu = await db.collection('users').doc(studentId).get();
    await db.collection('users').doc(studentId).set({'totalStars': (stu.data()?['totalStars'] ?? 0) + 1}, SetOptions(merge: true));
    return "تم اعطاء نجمة ⭐";
  }
  Future<String> buyItem(String itemId) async {
    String uid = auth.currentUser!.uid;
    var u = await db.collection('users').doc(uid).get();
    if (u.data()?['isBanned'] == true) return "انت محظور 🚫";
    int myStars = u.data()?['totalStars'] ?? 0;
    var item = await db.collection('shop').doc(itemId).get();
    int price = item.data()?['price'] ?? 10;
    if (myStars < price) return "نجومك ما بتكفي";
    await db.collection('users').doc(uid).update({'totalStars': myStars - price});
    return "تم الشراء ✅";
  }
  Future<void> reportUser(String reportedId, String reason) async {
    await db.collection('reports').add({'reporterId': auth.currentUser!.uid, 'reportedId': reportedId, 'reason': reason, 'status': 'pending', 'at': FieldValue.serverTimestamp()});
  }
}

class MainScreen extends StatefulWidget { @override _MainScreenState createState() => _MainScreenState(); }
class _MainScreenState extends State<MainScreen> {
  int i = 0;
  final pages = [HalaqatScreen(), ShopScreen(), XOGameScreen(), LinkQuizScreen(), SheikhScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[i],
      bottomNavigationBar: BottomNavigationBar(currentIndex: i, onTap: (v) => setState(() => i = v), type: BottomNavigationBarType.fixed, selectedItemColor: Colors.green, items: [
        BottomNavigationBarItem(icon: Icon(Icons.mosque), label: 'حلقات'),
        BottomNavigationBarItem(icon: Icon(Icons.store), label: 'المتجر'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_3x3), label: 'XO'),
        BottomNavigationBarItem(icon: Icon(Icons.link), label: 'الرابط'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'الشيخ'),
      ]),
    );
  }
}

class HalaqatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("حلقاتي 🕌")),
      body: StreamBuilder(stream: FirebaseFirestore.instance.collection('halaqat').snapshots(), builder: (c,s){
        if(!s.hasData) return Center(child: CircularProgressIndicator());
        if(s.data!.docs.isEmpty) return Center(child: ElevatedButton(onPressed: () async { var r = await AppService().createHalaqa("مسجد ابو بكر", "احمد"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r))); }, child: Text("انشئ حلقتك الأولى")));
        return ListView(children: s.data!.docs.map((d) => Card(child: ListTile(title: Text(d['halaqaName']), subtitle: Text(d['masjidName'])))).toList());
      }),
    );
  }
}

class ShopScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("المتجر الموحد ⭐")), body: StreamBuilder(stream: FirebaseFirestore.instance.collection('shop').snapshots(), builder: (c, s) {
      if (!s.hasData) return Center(child: CircularProgressIndicator());
      if (s.data!.docs.isEmpty) return Center(child: Text("المتجر فاضي - ضيف من Firebase"));
      return ListView(children: s.data!.docs.map((d) => ListTile(leading: Text(d['emoji'] ?? "⭐", style: TextStyle(fontSize: 28)), title: Text(d['name']), trailing: ElevatedButton(onPressed: () async { var r = await AppService().buyItem(d.id); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r))); }, child: Text("${d['price']} ⭐")))).toList());
    }));
  }
}

class XOGameScreen extends StatefulWidget { @override _XOGameScreenState createState() => _XOGameScreenState(); }
class _XOGameScreenState extends State<XOGameScreen> {
  List<String> b = List.filled(9, ""); String p = "⭐";
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("XO - ⭐ ضد 🌙")), body: Column(children: [Expanded(child: GridView.builder(padding: EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3), itemCount: 9, itemBuilder: (c, idx) => GestureDetector(onTap: () { if (b[idx] == "") setState(() { b[idx] = p; p = p == "⭐" ? "🌙" : "⭐"; }); }, child: Container(margin: EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)), child: Center(child: Text(b[idx], style: TextStyle(fontSize: 40)))))), ElevatedButton(onPressed: ()=>setState(()=>b=List.filled(9,"")), child: Text("اعادة"))]));
  }
}

class LinkQuizScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("سؤال الرابط 🔗")),
      body: StreamBuilder(stream: FirebaseFirestore.instance.collection('link_questions').snapshots(), builder: (c, s) {
        if (!s.hasData) return Center(child: CircularProgressIndicator());
        return ListView(children: s.data!.docs.map((d) {
          var data = d.data();
          return Card(margin: EdgeInsets.all(12), child: ListTile(title: Text(data['question'] ?? ""), subtitle: Text(data['article'] ?? ""), trailing: Icon(Icons.play_arrow), onTap: () {
            showDialog(context: context, builder: (_) => AlertDialog(title: Text(data['question']), content: Column(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
              String opt = data['options'][i];
              return Container(width: double.infinity, margin: EdgeInsets.only(top: 8), child: ElevatedButton(onPressed: () { if (opt == data['correctAnswer']) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("صح! ربحت ⭐"))); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("غلط - حاول مرة تانية"))); } }, child: Text(opt)));
            })),));
          }));
        }).toList());
      }),
      floatingActionButton: FloatingActionButton(onPressed: () async { await FirebaseFirestore.instance.collection('link_questions').add({'question': 'من هو نبي الاسلام؟', 'article': 'خاتم الانبياء ارسله الله رحمة للعالمين', 'options': ['محمد ﷺ', 'عيسى عليه السلام', 'موسى عليه السلام'], 'correctAnswer': 'محمد ﷺ'}); }, child: Icon(Icons.add)),
    );
  }
}

class SheikhScreen extends StatefulWidget { @override _SheikhScreenState createState() => _SheikhScreenState(); }
class _SheikhScreenState extends State<SheikhScreen> {
  TextEditingController ctrl = TextEditingController();
  List<Map<String,String>> msgs = [{"role":"sheikh", "text":"السلام عليكم يا بني 🌙 أنا الشيخ الذكي، اسألني أي سؤال بالدين"}];
  bool loading = false;
  Future<String> askSheikh(String q) async {
    await Future.delayed(Duration(seconds: 1));
    q = q.toLowerCase();
    if (q.contains("صلاة")) return "الصلاة عماد الدين، حافظ عليها بوقتها. قال ﷺ: العهد الذي بيننا وبينهم الصلاة";
    if (q.contains("محمد")) return "نبينا محمد ﷺ خاتم الانبياء، ارسله الله رحمة للعالمين. اكثر من الصلاة عليه";
    return "سؤالك: $q\nالجواب: هذا من امور الدين، انصحك بسؤال شيخ حلقتك والتأكد من المصادر الموثوقة 🌙";
  }
  void send() async {
    if(ctrl.text.trim().isEmpty) return;
    String q = ctrl.text;
    setState(() { msgs.add({"role":"user", "text":q}); loading = true; ctrl.clear(); });
    String ans = await askSheikh(q);
    setState(() { msgs.add({"role":"sheikh", "text":ans}); loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("الشيخ الذكي 🧠")),
      body: Column(children: [
        Expanded(child: ListView.builder(padding: EdgeInsets.all(12), itemCount: msgs.length, itemBuilder: (c,i){
          bool isUser = msgs[i]['role'] == 'user';
          return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: isUser ? Colors.green[100] : Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Text(msgs[i]['text']!)));
        })),
        if(loading) Text("الشيخ عم يكتب... ✍️"),
        Container(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: "اسأل الشيخ...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), SizedBox(width: 8), FloatingActionButton(mini: true, onPressed: send, child: Icon(Icons.send))]))
      ]),
    );
  }
}
