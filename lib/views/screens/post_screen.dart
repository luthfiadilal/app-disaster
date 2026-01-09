import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/post_controller.dart';
import '../components/post_card.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch posts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostController>().fetchPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MVC Posts'), centerTitle: true),
      body: Consumer<PostController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${controller.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.fetchPosts(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (controller.posts.isEmpty) {
            return const Center(child: Text('No posts found'));
          }

          return RefreshIndicator(
            onRefresh: () => controller.fetchPosts(),
            child: ListView.builder(
              itemCount: controller.posts.length,
              itemBuilder: (context, index) {
                final post = controller.posts[index];
                return PostCard(post: post);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<PostController>().fetchPosts(),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
