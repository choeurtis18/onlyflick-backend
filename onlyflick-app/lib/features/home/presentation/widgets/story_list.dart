import 'package:flutter/material.dart';

class StoryList extends StatelessWidget {
  const StoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: index == 0 
                        ? null 
                        : const LinearGradient(
                            colors: [Colors.purple, Colors.pink, Colors.orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    border: index == 0 
                        ? Border.all(color: Colors.grey, width: 2)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: index == 0 ? 26 : 28,
                      backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150?img=${index + 1}',
                      ),
                      child: index == 0 
                          ? const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  index == 0 ? 'Votre story' : 'user$index',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}