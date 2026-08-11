import 'package:flutter/material.dart';
import '../services/save_service.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget { const LevelSelectScreen({super.key}); @override State<LevelSelectScreen> createState()=>_LevelSelectState(); }
class _LevelSelectState extends State<LevelSelectScreen> {
  final save = SaveService();
  @override void initState(){super.initState(); save.load().then((_)=>setState((){}));}
  @override Widget build(BuildContext context){
    final names=['First Shot','Long Shot','Head Hunter','Moving Target','First Battle','Undead Arrival','The Hunted Pair','Twin Terror'];
    return Scaffold(backgroundColor: const Color(0xFF0B1016), appBar: AppBar(title: const Text('LEVEL SELECT')), body: ListView.builder(itemCount:names.length,itemBuilder:(context,i){final n=i+1; final unlocked=n<=save.unlockedLevel; return ListTile(enabled:unlocked, leading:Icon(unlocked?Icons.play_arrow:Icons.lock), title:Text('LEVEL $n — ${names[i]}'), trailing:save.completedLevels.contains(n)?const Icon(Icons.check,color:Colors.green):null,onTap:unlocked?()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>GameScreen(levelNumber:n,onCompleted: () async {
                          await save.completeLevel(n);
                          if (mounted) setState(() {});
                        } ))):null); }));
  }
}
