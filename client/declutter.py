import numpy as np
import math
import cv2

import video
from rmsocket import RomoSocket

# THRESHOLDS
SLOPE_DIFF_THRESHOLD = 10
ANGLE_DIFF_THRESHOLD = 5
GOAL_DIST_THRESHOLD = 5

H_MIN = 0
H_MAX = 255
S_MIN = 0
S_MAX = 255
V_MIN = 0
V_MAX = 255

GOAL_X = 200
GOAL_Y = 200

GOAL_POS = (GOAL_X, GOAL_Y)

# orange in box
H_MIN_BALL = 0
H_MAX_BALL = 255
S_MIN_BALL = 200
S_MAX_BALL = 255
V_MIN_BALL = 160
V_MAX_BALL = 255

# romo front in box
H_MIN_ROMO_F = 40
H_MAX_ROMO_F = 255
S_MIN_ROMO_F = 5
S_MAX_ROMO_F = 255
V_MIN_ROMO_F = 200
V_MAX_ROMO_F = 255

# romo back in box
H_MIN_ROMO_B = 30
H_MAX_ROMO_B = 30
S_MIN_ROMO_B = 45
S_MAX_ROMO_B = 120
V_MIN_ROMO_B = 255
V_MAX_ROMO_B = 255

BALL_MIN_HSV = np.array([H_MIN_BALL, S_MIN_BALL, V_MIN_BALL], np.uint8)
BALL_MAX_HSV = np.array([H_MAX_BALL, S_MAX_BALL, V_MAX_BALL], np.uint8)

ROMO_F_MIN_HSV = np.array([H_MIN_ROMO_F, S_MIN_ROMO_F, V_MIN_ROMO_F], np.uint8)
ROMO_F_MAX_HSV = np.array([H_MAX_ROMO_F, S_MAX_ROMO_F, V_MAX_ROMO_F], np.uint8)

ROMO_B_MIN_HSV = np.array([H_MIN_ROMO_B, S_MIN_ROMO_B, V_MIN_ROMO_B], np.uint8)
ROMO_B_MAX_HSV = np.array([H_MAX_ROMO_B, S_MAX_ROMO_B, V_MAX_ROMO_B], np.uint8)

# default capture width and height
FRAME_WIDTH = 640
FRAME_HEIGHT = 480

# max number of objects to be detected in frame
MAX_NUM_OBJECTS = 50

# minimum and maximum object area
MIN_OBJECT_AREA = 20 * 20
MAX_OBJECT_AREA = FRAME_HEIGHT * FRAME_WIDTH / 1.5

# UI
ORANGE = (0, 102, 255)
PURPLE = (153, 51, 102)
BLUE = (255, 0, 0)

# names that will appear at the top of each window
WINDOW_NAME = "Original Image"
HSV_WINDOW = "HSV Image"
ROMO_FRONT_THRESHOLD_WINDOW = "Romo Front Thresholded Image"
ROMO_BACK_THRESHOLD_WINDOW = "Romo Back Thresholded Image"
BALL_THRESHOLD_WINDOW = "Ball Thresholded Image"
EXPERIMENT_THRESHOLD_WINDOW = "Experiment Thresholded Image"

def draw_object(x, y, frame, color=(0, 255, 0)):
    x, y = int(x), int(y)
    cv2.circle(frame, (x, y), 20, color, 2)
    cv2.line(frame, (x, clamp_height(y + 25)), (x, clamp_height(y - 25)), color, 2)
    cv2.line(frame ,(clamp_width(x + 25), y), (clamp_width(x - 25), y), color, 2)
    cv2.putText(frame, str(x) + ", " + str(y), (x, clamp_height(y + 50)), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)

# perform morphological operations on thresholded image to eliminate noise and
# emphasize the filtered object(s)
def morph_ops(thresh):
    # create structuring element that will be used to "dilate" and "erode" image.
    # the element chosen here is a 3px by 3px rectangle
    erode_element = cv2.getStructuringElement(cv2.MORPH_RECT, (3,3))
    # dilate with larger element so make sure object is nicely visible
    dilate_element = cv2.getStructuringElement(cv2.MORPH_RECT, (8,8))

    cv2.erode(thresh, erode_element, thresh)
    cv2.erode(thresh, erode_element, thresh)

    cv2.dilate(thresh, dilate_element, thresh)
    cv2.dilate(thresh, dilate_element, thresh)

def track_filtered_object(threshold, camera_feed):
    # find contours of filtered image using openCV findContours function
    temp = threshold.copy()
    contours, hierarchy = cv2.findContours(temp, cv2.cv.CV_RETR_CCOMP,
                                           cv2.cv.CV_CHAIN_APPROX_SIMPLE)

    # use moments method to find our filtered object
    ref_area = 0
    object_pos = ()
    if hierarchy is not None and len(hierarchy) > 0:
        # more than MAX_NUM_OBJECTS: noisy filter
        if len(hierarchy) < MAX_NUM_OBJECTS:
            index = 0
            while index >= 0:
                moment = cv2.moments(contours[index])
                area = moment['m00']

                # less than MIN_OBJECT_AREA: probably just noise
                # less than reference area: already saw one bigger
                if area > MIN_OBJECT_AREA and area > ref_area:
                    x = moment['m10'] / area
                    y = moment['m01'] / area
                    ref_area = area
                    object_pos = (x, y)

                try:
                    index = hierarchy[index][0][0]
                except IndexError:
                    index = -1

            if object_pos:
                return object_pos

        else:
            print "TOO MUCH NOISE! ADJUST FILTER"


def clamp(x, lo, hi):
    return hi if (x > hi) else (lo if (x < lo) else x)

def clamp_255(x):
    return clamp(x, 0, 255)

def clamp_width(x):
    return clamp(x, 0, FRAME_WIDTH)

def clamp_height(x):
    return clamp(x, 0, FRAME_HEIGHT)


def set_width_height(width, height):
    global FRAME_WIDTH, FRAME_HEIGHT, MAX_OBJECT_AREA, MIN_OBJECT_AREA

    width, height = int(width), int(height)
    area = width * height
    FRAME_WIDTH, FRAME_HEIGHT = width, height
    MAX_OBJECT_AREA, MIN_OBJECT_AREA = area / 1.5,  area / 1500.0

# helper method that allows you to tune HSV while the script is running instead
# of having to restart the script.
def tune_hsv(char):
    global H_MIN, H_MAX, S_MIN, S_MAX, V_MIN, V_MAX
    if char == ord('h'):
        H_MIN = clamp_255(H_MIN + 5)
    if char == ord('n'):
        H_MIN = clamp_255(H_MIN - 5)
    if char == ord('j'):
        H_MAX = clamp_255(H_MAX + 5)
    if char == ord('m'):
        H_MAX = clamp_255(H_MAX - 5)
    if char == ord('s'):
        S_MIN = clamp_255(S_MIN + 5)
    if char == ord('x'):
        S_MIN = clamp_255(S_MIN - 5)
    if char == ord('d'):
        S_MAX = clamp_255(S_MAX + 5)
    if char == ord('c'):
        S_MAX = clamp_255(S_MAX - 5)
    if char == ord('v'):
        V_MIN = clamp_255(V_MIN + 5)
    if char == ord('f'):
        V_MIN = clamp_255(V_MIN - 5)
    if char == ord('b'):
        V_MAX = clamp_255(V_MAX + 5)
    if char == ord('g'):
        V_MAX = clamp_255(V_MAX - 5)
    if char == ord('p'):
        print "H_MIN: {0} H_MAX: {1} S_MIN: {2} S_MAX: {3} V_MIN: {4} V_MAX: {5}".format(H_MIN, H_MAX, S_MIN, S_MAX, V_MIN, V_MAX)


def get_angle_of_slope(rise, run):
    return math.atan2(rise, run)

def get_angle_between(p0, p1):
    return math.degrees(math.atan2(p1[1] - p0[1], float(p1[0] - p0[0])))

def get_dist(p0, p1):
    return math.sqrt((p0[0] - p1[0])**2 + (p0[1] - p1[1])**2)

def get_midpoint(p0, p1):
    return ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)

def is_point_in_box(point, box):
    px, py = point
    box_top_left, box_bottom_right = box
    btx, bty = box_top_left
    bbx, bby = box_bottom_right
    return btx <= px and px <= bbx and bty <= py and py <= bby


# get angle diff in range [-180, 180]
def get_angle_diff(angle1, angle2):
    diff = (angle1 - angle2) % 360
    if diff > 180:
        return x - 360
    if diff < -180:
        return x + 360


class Romo:
    def __init__(self):
        self.romo_ws = RomoSocket()
        self.target = None
        self.initial_heading = None
        self.initial_front_pos = None
        self.initial_back_pos = None
        self.front_pos = None
        self.back_pos = None

    def get_heading(self):
        return get_angle_between(self.back_pos, self.front_pos)

    def get_center(self):
        return get_midpoint(self.front_pos, self.back_pos)

    def turn(self, direction=1, power=0.65):
        self.romo_ws.send_turn(direction, power)

    def forward(self, speed=0.25):
        self.romo_ws.send_drive_forward(speed)

    def backward(self, speed=0.25):
        self.romo_ws.send_drive_backward(speed)

    def stop(self):
        self.romo_ws.send_stop()

    def get_bounding_box(self):
        cx, cy = self.get_center()
        # account for wedge in front and index card on back
        dim = get_dist(self.front_pos, self.back_pos) * 1.1
        radius = dim / 2
        top_left = (cx - radius, cy - radius)
        bottom_right = (cx + radius, cy + radius)
        return (top_left, bottom_right)

    def is_clutter_in_bounding_box(self, clutter_center):
        return is_point_in_box(clutter_center, self.get_bounding_box())

    def move_away_from_clutter(self, clutter_center):
        if get_dist(self.front_pos, clutter_center) < get_dist(self.back_pos, clutter_center):
            self.backward()
        else:
            self.forward()

    # TODO: deal with cases where romo would disturb clutter
    def move_to_point(self, point):
        heading = get_angle_between(self.front_pos, point)
        if self.turn_to_heading(heading):
            if get_dist(self.get_center(), point) < GOAL_DIST_THRESHOLD:
                self.stop()
            else:
                self.forward()

    def is_clutter_between_goal(self, goal_center, clutter_center):
        angle_c = get_angle_between(clutter_center, goal_center)
        angle_r = get_angle_between(self.front_pos, goal_center)

        dist = get_dist(self.front_pos, goal_center)
        clutter_dist = get_dist(clutter_center, goal_center)

        is_on_line = abs(get_angle_diff(angle_c, angle_r)) < ANGLE_DIFF_THRESHOLD
        is_further = dist > clutter_dist
        return is_on_line and is_further

    # direction: 1 = CW (increasing heading), -1 = CCW (decreasing heading)
    def turn_to_heading(self, angle):
        diff = get_angle_diff(self.get_heading(), angle)
        is_at_heading = abs(diff) < ANGLE_DIFF_THRESHOLD

        if is_at_heading:
            self.stop()
        else:
            self.turn(1 if (diff < 0) else -1)

        return is_at_heading


def get_start_pt(goal_center, clutter_center):
    rise = clutter_center[1] - goal_center[1]
    run = clutter_center[0] - goal_center[0]
    angle = get_angle_of_slope(rise, run)
    x_cmp = math.cos(angle) * 150
    y_cmp = math.sin(angle) * 150

    return (int(clutter_center[0] + x_cmp), int(clutter_center[1] + y_cmp))


if __name__ == '__main__':
    capture = video.create_capture(0)
    romo = Romo()

    while True:
        _, camera_feed = capture.read()
        set_width_height(camera_feed.shape[1] / 2, camera_feed.shape[0] / 2)

        mini_size = (FRAME_WIDTH, FRAME_HEIGHT)
        camera_feed = cv2.resize(camera_feed, mini_size)

        # convert frame from BGR to HSV colorspace
        hsv_img = cv2.cvtColor(camera_feed, cv2.COLOR_BGR2HSV)
        romo_f_threshold = cv2.inRange(hsv_img, ROMO_F_MIN_HSV, ROMO_F_MAX_HSV)
        romo_b_threshold = cv2.inRange(hsv_img, ROMO_B_MIN_HSV, ROMO_B_MAX_HSV)
        ball_threshold = cv2.inRange(hsv_img, BALL_MIN_HSV, BALL_MAX_HSV)
        threshold = cv2.inRange(hsv_img,
                                np.array([H_MIN,S_MIN,V_MIN], np.uint8),
                                np.array([H_MAX,S_MAX,V_MAX], np.uint8))

        morph_ops(romo_f_threshold)
        morph_ops(romo_b_threshold)
        morph_ops(ball_threshold)
        morph_ops(threshold)

        romo_f_pos = track_filtered_object(romo_f_threshold, camera_feed)
        romo_b_pos = track_filtered_object(romo_b_threshold, camera_feed)
        ball_pos = track_filtered_object(ball_threshold, camera_feed)
        training_pos = track_filtered_object(threshold, camera_feed)

        draw_object(GOAL_X, GOAL_Y, camera_feed)

        if romo_f_pos:
            draw_object(romo_f_pos[0], romo_f_pos[1], camera_feed, ORANGE)
        if romo_b_pos:
            draw_object(romo_b_pos[0], romo_b_pos[1], camera_feed, PURPLE)
        if ball_pos:
            draw_object(ball_pos[0], ball_pos[1], camera_feed, BLUE)

        if romo_f_pos and romo_b_pos and ball_pos:
            romo.front_pos, romo.back_pos = romo_f_pos, romo_b_pos
            if romo.is_clutter_in_bounding_box(ball_pos):
                romo.move_away_from_clutter(ball_pos)
            else:
                if romo.is_clutter_between_goal(GOAL_POS, ball_pos):
                    romo.move_to_point(GOAL_POS)
                    draw_object(GOAL_X, GOAL_Y, camera_feed, (0, 0, 255))
                else:
                    start_pt = get_start_pt(GOAL_POS, ball_pos)
                    romo.move_to_point(start_pt)
                    draw_object(start_pt[0], start_pt[1], camera_feed, (0, 0, 255))
       else:
           if ball_pos:
               if romo_f_pos:
                   romo.forward()
               elif romo_b_pos:
                   romo.backward()
               else:
                   romo.stop()
           else:
               romo.stop()

        # show frames
        cv2.imshow(WINDOW_NAME, camera_feed)
        # cv2.imshow(HSV_WINDOW, hsv_img)
        # cv2.imshow(ROMO_FRONT_THRESHOLD_WINDOW, romo_f_threshold)
        # cv2.imshow(ROMO_BACK_THRESHOLD_WINDOW, romo_b_threshold)
        # cv2.imshow(BALL_THRESHOLD_WINDOW, ball_threshold)
        # cv2.imshow(EXPERIMENT_THRESHOLD_WINDOW, threshold)

        # tune_hsv(cv2.waitKey(30))
