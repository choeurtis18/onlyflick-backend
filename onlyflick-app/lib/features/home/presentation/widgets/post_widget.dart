import 'package:flutter/material.dart';
import 'post_list.dart';

class PostWidget extends StatefulWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late int likeCount;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post.likes;
  }

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(widget.post.userImage),
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.post.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.black),
            ],
          ),
        ),

        // Post image
        AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            widget.post.postImage,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),

        // Post actions
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: toggleLike,
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.mode_comment_outlined, color: Colors.black, size: 26),
              const SizedBox(width: 16),
              const Icon(Icons.send_outlined, color: Colors.black, size: 24),
              const Spacer(),
              const Icon(Icons.bookmark_border, color: Colors.black),
            ],
          ),
        ),

        // Likes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$likeCount Likes',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),

        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.post.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: widget.post.description,
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}
