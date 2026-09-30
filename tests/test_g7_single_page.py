import os
import unittest
import json

class TestG7SinglePage(unittest.TestCase):
    def setUp(self):
        self.docs_dir = os.path.join(os.path.dirname(__file__), '..', 'docs')
        self.index_path = os.path.join(self.docs_dir, 'index.html')

    def test_single_page_exists(self):
        self.assertTrue(os.path.exists(self.index_path))
    
    def test_anchors_exist(self):
        with open(self.index_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        self.assertIn('id="home"', content)
        self.assertIn('id="explore"', content)
        self.assertIn('id="statistics"', content)
        self.assertIn('id="machine-learning"', content)
        
    def test_redirects_exist(self):
        for page in ['explore.html', 'statistics.html', 'machine-learning.html']:
            path = os.path.join(self.docs_dir, page)
            self.assertTrue(os.path.exists(path))
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            self.assertIn('window.location.replace', content)

    def test_scientific_baseline_untouched(self):
        # Ensure we didn't accidentally delete models or data
        self.assertTrue(os.path.exists(os.path.join(os.path.dirname(__file__), '..', 'models')))
        self.assertTrue(os.path.exists(os.path.join(os.path.dirname(__file__), '..', 'data')))

if __name__ == '__main__':
    unittest.main()
