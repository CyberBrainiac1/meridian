import numpy as np

from meridian_hub.vision.fast_ops import greedy_match_by_iou, greedy_nms, iou_matrix


def test_iou_matrix_identical_boxes_is_one():
    boxes = np.array([[0.0, 0.0, 10.0, 10.0]], dtype=np.float32)
    result = iou_matrix(boxes, boxes)
    assert result.shape == (1, 1)
    assert abs(result[0, 0] - 1.0) < 1e-6


def test_iou_matrix_disjoint_boxes_is_zero():
    a = np.array([[0.0, 0.0, 10.0, 10.0]], dtype=np.float32)
    b = np.array([[100.0, 100.0, 110.0, 110.0]], dtype=np.float32)
    result = iou_matrix(a, b)
    assert result[0, 0] == 0.0


def test_iou_matrix_shape_matches_inputs():
    a = np.array([[0, 0, 10, 10], [20, 20, 30, 30], [40, 40, 50, 50]], dtype=np.float32)
    b = np.array([[0, 0, 10, 10], [100, 100, 110, 110]], dtype=np.float32)
    result = iou_matrix(a, b)
    assert result.shape == (3, 2)
    assert result[0, 0] == 1.0
    assert result[0, 1] == 0.0


def test_iou_matrix_handles_empty_input():
    empty = np.zeros((0, 4), dtype=np.float32)
    nonempty = np.array([[0, 0, 10, 10]], dtype=np.float32)
    assert iou_matrix(empty, nonempty).shape == (0, 1)
    assert iou_matrix(nonempty, empty).shape == (1, 0)


def test_greedy_nms_keeps_highest_score_suppresses_overlap():
    boxes = np.array([
        [0, 0, 10, 10],
        [1, 1, 11, 11],  # heavily overlaps box 0
        [100, 100, 110, 110],  # distinct
    ], dtype=np.float32)
    scores = np.array([0.9, 0.7, 0.85], dtype=np.float32)
    kept = greedy_nms(boxes, scores, iou_threshold=0.5)
    assert 0 in kept  # higher-scoring of the overlapping pair
    assert 1 not in kept  # suppressed
    assert 2 in kept  # distinct box survives


def test_greedy_nms_empty_input_returns_empty():
    assert greedy_nms(np.zeros((0, 4), dtype=np.float32), np.zeros(0, dtype=np.float32), 0.5) == []


def test_greedy_nms_no_overlap_keeps_everything():
    boxes = np.array([[0, 0, 10, 10], [100, 100, 110, 110]], dtype=np.float32)
    scores = np.array([0.5, 0.6], dtype=np.float32)
    kept = greedy_nms(boxes, scores, iou_threshold=0.5)
    assert set(kept) == {0, 1}


def test_greedy_match_pairs_best_overlap_first():
    # track 0 overlaps detection 1 strongly; track 1 overlaps detection 0 strongly
    cost = np.array([
        [0.1, 0.9],
        [0.8, 0.05],
    ], dtype=np.float32)
    matches = greedy_match_by_iou(cost, min_iou=0.3)
    assert (0, 1) in matches
    assert (1, 0) in matches
    assert len(matches) == 2


def test_greedy_match_respects_threshold():
    cost = np.array([[0.1, 0.2]], dtype=np.float32)
    matches = greedy_match_by_iou(cost, min_iou=0.3)
    assert matches == []


def test_greedy_match_each_row_and_col_used_once():
    cost = np.array([
        [0.9, 0.8, 0.1],
        [0.85, 0.1, 0.1],
    ], dtype=np.float32)
    matches = greedy_match_by_iou(cost, min_iou=0.3)
    rows = [m[0] for m in matches]
    cols = [m[1] for m in matches]
    assert len(rows) == len(set(rows))
    assert len(cols) == len(set(cols))
