import 'package:flutter/material.dart';
import '../../components/news_card.dart';
import '../../services/news_service.dart';
import '../../components/shimmer_loading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class AllNewsScreen extends StatefulWidget {
  const AllNewsScreen({super.key});

  @override
  State<AllNewsScreen> createState() => _AllNewsScreenState();
}

class _AllNewsScreenState extends State<AllNewsScreen> {
  List<NewsArticle> _newsArticles = [];
  bool _loadingNews = true;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Tech', 'Business', 'Sports', 'Health', 'Science', 'Entertainment'];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      List<NewsArticle> articles;
      switch (_selectedCategory) {
        case 'Tech':
          articles = await NewsService.getTechNews();
          break;
        case 'Business':
          articles = await NewsService.getBusinessNews();
          break;
        case 'Sports':
          articles = await NewsService.getSportsNews();
          break;
        case 'Health':
          articles = await NewsService.getHealthNews();
          break;
        case 'Science':
          articles = await NewsService.getScienceNews();
          break;
        case 'Entertainment':
          articles = await NewsService.getEntertainmentNews();
          break;
        default:
          articles = await NewsService.getAllNews();
      }
      
      if (mounted) {
        setState(() {
          _newsArticles = articles;
          _loadingNews = false;
        });
      }
    } catch (e) {
      print('Error loading news: $e');
      if (mounted) {
        setState(() {
          _loadingNews = false;
        });
      }
    }
  }

  Future<void> _refreshNews() async {
    setState(() {
      _loadingNews = true;
    });
    await _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All News',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF87CEEB), Color(0xFF2196F3)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _refreshNews,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            tooltip: 'Refresh news',
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter scrollbar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF667eea),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected && category != _selectedCategory) {
                        setState(() {
                          _selectedCategory = category;
                          _loadingNews = true;
                        });
                        _loadNews();
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF667eea),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF667eea) : Colors.grey[300]!,
                    ),
                    elevation: isSelected ? 4 : 0,
                    shadowColor: const Color(0xFF667eea).withOpacity(0.3),
                  ),
                );
              },
            ),
          ),
          
          // News list
          Expanded(
            child: _buildNewsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsContent() {
    if (_loadingNews) {
      return Shimmer(
        linearGradient: const LinearGradient(
          colors: [
            Color(0xFFEBEBF4),
            Color(0xFFF4F4F4),
            Color(0xFFEBEBF4),
          ],
          stops: [0.1, 0.3, 0.4],
          begin: Alignment(-1.0, -0.3),
          end: Alignment(1.0, 0.3),
          tileMode: TileMode.clamp,
        ),
        child: ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) {
            return ShimmerLoading(
              isLoading: true,
              child: NewsShimmerCard(),
            );
          },
        ),
      );
    }

    if (_newsArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 60,
                color: Color(0xFF667eea),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No news available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF667eea),
      onRefresh: _refreshNews,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _newsArticles.length + 1, // +1 for bottom spacing
        itemBuilder: (context, index) {
          if (index == _newsArticles.length) {
            return const SizedBox(height: 20); // Bottom spacing
          }
          
          return NewsCard(article: _newsArticles[index]);
        },
      ),
    );
  }
}