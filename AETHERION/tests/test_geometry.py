"""Run with normal Python; these tests do not simulate Blender."""
import importlib.util
from pathlib import Path
import unittest
from collections import Counter

path=Path(__file__).resolve().parents[1]/'blender'/'geometry.py'
spec=importlib.util.spec_from_file_location('geometry',path)
g=importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)


class GeometryTests(unittest.TestCase):
    def closed(self, data):
        vertices,faces=data
        g.validate(vertices,faces)
        edges=Counter()
        for f in faces:
            for a,b in zip(f,f[1:]+f[:1]):
                edges[tuple(sorted((a,b)))]+=1
        self.assertTrue(all(n==2 for n in edges.values()))

    def test_stones_are_closed_and_deterministic(self):
        for rings in (3,5):
            for seed in range(50):
                data=g.stone((4,3,2),seed,rings)
                self.closed(data)
                self.assertEqual(data,g.stone((4,3,2),seed,rings))
                self.assertEqual(min(v[2] for v in data[0]),-1)
                self.assertEqual(max(v[2] for v in data[0]),1)

    def test_crystal_and_arch_topology(self):
        self.closed(g.crystal(3,5,2))
        self.closed(g.arc(9,.3,.4,steps=64))
        self.closed(g.arc(3,.3,.4,0,3.14,18))

    def test_cloth_grid_curved_and_indices_valid(self):
        for side in (-1,0,1):
            vertices,faces=g.cloth(3,12,side,6,12)
            g.validate(vertices,faces)
            self.assertEqual(len(vertices),91)
            self.assertEqual(len(faces),72)
            self.assertGreater(max(v[1] for v in vertices)-min(v[1] for v in vertices),.5)


if __name__=='__main__':
    unittest.main()
