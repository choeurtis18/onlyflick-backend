import 'package:flutter/material.dart';
import 'post_widget.dart';

class PostList extends StatelessWidget {
  PostList({super.key});

  final List<Post> posts = List.generate(
    5,
    (index) => Post(
      username: 'user$index',
      userImage: 'https://i.pravatar.cc/150?img=${index + 5}',
      postImage: 'https://picsum.photos/seed/post$index/400/400',
      description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      likes: 100 + index * 13,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PostWidget(post: posts[index]),
        );
      },
    );
  }
}

class Post {
  final String username;
  final String userImage;
  final String postImage;
  final String description;
  final int likes;

  Post({
    required this.username,
    required this.userImage,
    required this.postImage,
    required this.description,
    required this.likes,
  });
}
