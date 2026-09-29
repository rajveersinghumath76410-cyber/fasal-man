from pathlib import Path
from uuid import uuid4

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError


# =========================================================
# FASAL MAN - ONION QUALITY ASSESSMENT API
# Computer Vision MVP
# =========================================================

APP_NAME = "Fasal Man Onion Quality API"
VERSION = "2.2.0"

BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "uploads"

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
}

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


app = FastAPI(
    title=APP_NAME,
    version=VERSION,
    description=(
        "Computer-vision based indicative onion quality "
        "assessment API for Fasal Man."
    ),
)


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# ROOT
# =========================================================

@app.get("/")
async def root():
    return {
        "success": True,
        "message": "Fasal Man Onion Quality API is running.",
        "version": VERSION,
        "docs": "/docs",
        "health": "/health",
        "assessment_endpoint": "/api/v1/assess-onion",
    }


# =========================================================
# HEALTH CHECK
# =========================================================

@app.get("/health")
async def health():
    return {
        "success": True,
        "status": "ok",
        "service": APP_NAME,
        "version": VERSION,
        "computer_vision": "OpenCV",
    }


# =========================================================
# IMAGE VALIDATION
# =========================================================

async def validate_image(file: UploadFile) -> bytes:

    if not file.filename:
        raise HTTPException(
            status_code=400,
            detail="No filename was provided.",
        )

    extension = Path(file.filename).suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=(
                "Unsupported image format. "
                "Use JPG, JPEG, PNG, or WEBP."
            ),
        )

    contents = await file.read()

    if not contents:
        raise HTTPException(
            status_code=400,
            detail="The uploaded image is empty.",
        )

    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="Image is too large. Maximum size is 10 MB.",
        )

    return contents


# =========================================================
# IMAGE INFORMATION
# =========================================================

def read_image_info(image_path: Path) -> dict:

    try:

        with Image.open(image_path) as image:

            image_format = image.format
            width, height = image.size
            mode = image.mode

            # Force decoding so corrupted images are detected.
            image.load()

    except UnidentifiedImageError:

        raise HTTPException(
            status_code=400,
            detail="The uploaded file is not a valid image.",
        )

    except Exception as exc:

        raise HTTPException(
            status_code=400,
            detail=f"Invalid or unreadable image: {exc}",
        )

    return {
        "format": image_format,
        "width": width,
        "height": height,
        "mode": mode,
    }


# =========================================================
# OPENCV IMAGE LOADING
# =========================================================

def load_cv_image(image_path: Path) -> np.ndarray:

    image = cv2.imread(
        str(image_path),
        cv2.IMREAD_COLOR,
    )

    if image is None:

        raise HTTPException(
            status_code=400,
            detail="OpenCV could not read the uploaded image.",
        )

    return image


# =========================================================
# FOREGROUND / ONION MASK
# =========================================================

def create_foreground_mask(
    image: np.ndarray,
) -> np.ndarray:

    height, width = image.shape[:2]

    hsv = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2HSV,
    )

    saturation = hsv[:, :, 1]
    value = hsv[:, :, 2]

    # Broad foreground estimate for colored onions.
    colored = (
        (saturation > 18) &
        (value > 30)
    ).astype(np.uint8) * 255

    # Also allow bright, low-saturation onions,
    # such as white onions.
    bright = (
        (saturation <= 45) &
        (value > 105)
    ).astype(np.uint8) * 255

    mask = cv2.bitwise_or(
        colored,
        bright,
    )

    kernel = np.ones(
        (7, 7),
        np.uint8,
    )

    mask = cv2.morphologyEx(
        mask,
        cv2.MORPH_OPEN,
        kernel,
    )

    mask = cv2.morphologyEx(
        mask,
        cv2.MORPH_CLOSE,
        kernel,
    )

    contours, _ = cv2.findContours(
        mask,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE,
    )

    clean_mask = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    min_area = max(
        100,
        int(height * width * 0.005),
    )

    for contour in contours:

        if cv2.contourArea(contour) >= min_area:

            cv2.drawContours(
                clean_mask,
                [contour],
                -1,
                255,
                thickness=cv2.FILLED,
            )

    return clean_mask


# =========================================================
# ONION CONTOURS
# =========================================================

def find_onion_contours(
    mask: np.ndarray,
    image_shape: tuple,
) -> list:

    height, width = image_shape[:2]

    image_area = height * width

    contours, _ = cv2.findContours(
        mask,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE,
    )

    valid = []

    for contour in contours:

        area = cv2.contourArea(
            contour
        )

        if area < image_area * 0.005:
            continue

        x, y, w, h = cv2.boundingRect(
            contour
        )

        if w < 20 or h < 20:
            continue

        valid.append(contour)

    return valid


# =========================================================
# ONION IMAGE VALIDATION
# =========================================================

def validate_onion_image(
    image: np.ndarray,
    mask: np.ndarray,
    contours: list,
) -> tuple[bool, str, float]:
    """Heuristic gate for onion photographs.

    The validator deliberately does not depend on the foreground mask being
    perfect. This matters for real onion-market photos where many onions touch
    each other and the foreground can become one large connected region.
    """

    height, width = image.shape[:2]

    if width < 160 or height < 160:
        return (
            False,
            "Image is too small for reliable onion assessment.",
            0.0,
        )

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    brightness = float(np.mean(gray))
    contrast = float(np.std(gray))

    if brightness < 15 or contrast < 7:
        return (
            False,
            "Image is too dark or unclear. Please upload a clear onion image.",
            0.0,
        )

    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    hue = hsv[:, :, 0]
    saturation = hsv[:, :, 1]
    value = hsv[:, :, 2]

    # Red/purple onion signature. This is intentionally broad enough to
    # include common red onions photographed under different lighting.
    red_purple = (
        (
            ((hue >= 0) & (hue <= 18))
            | ((hue >= 145) & (hue <= 179))
        )
        & (saturation >= 35)
        & (value >= 35)
    )

    red_purple_ratio = float(np.mean(red_purple))
    mean_saturation = float(np.mean(saturation))
    mean_value = float(np.mean(value))

    # Onion photos usually contain substantial fine texture from skins,
    # roots, and overlapping bulbs. Edge density helps distinguish a
    # strongly colored object/photo from a nearly uniform color field.
    edges = cv2.Canny(gray, 60, 150)
    edge_density = float(np.mean(edges > 0))

    # ------------------------------------------------------------
    # Special path for dense red/purple onion photographs
    # ------------------------------------------------------------
    #
    # A market/basket image can legitimately produce one contour covering
    # almost the entire frame because adjacent onions touch. The previous
    # validator rejected this as "area_ratio > 0.75". Instead, use the
    # image-wide onion color signature in this situation.
    dense_red_onion_photo = (
        red_purple_ratio >= 0.45
        and mean_saturation >= 75
        and mean_value >= 45
        and edge_density >= 0.05
    )

    if dense_red_onion_photo:
        confidence = np.clip(
            0.55
            + 0.30 * np.clip((red_purple_ratio - 0.45) / 0.50, 0.0, 1.0)
            + 0.15 * np.clip((edge_density - 0.05) / 0.20, 0.0, 1.0),
            0.0,
            0.98,
        )

        return (
            True,
            "Red/purple onion photo accepted for visual assessment.",
            round(float(confidence), 2),
        )

    # ------------------------------------------------------------
    # General single/few-onion contour path
    # ------------------------------------------------------------

    if not contours:
        return (
            False,
            "No onion-like object was detected. Please upload a clear photo of onions.",
            0.05,
        )

    image_area = float(height * width)
    candidates = []
    best_score = 0.0

    for contour in contours:
        area = float(cv2.contourArea(contour))
        if area <= 0:
            continue

        x, y, w, h = cv2.boundingRect(contour)

        if w < 30 or h < 30:
            continue

        area_ratio = area / image_area
        aspect = max(w / h, h / w)

        perimeter = cv2.arcLength(contour, True)
        circularity = (
            (4.0 * np.pi * area) / (perimeter * perimeter)
            if perimeter > 0
            else 0.0
        )

        hull = cv2.convexHull(contour)
        hull_area = float(cv2.contourArea(hull))
        solidity = area / hull_area if hull_area > 0 else 0.0

        rect_area = float(w * h)
        extent = area / rect_area if rect_area > 0 else 0.0

        contour_mask = np.zeros((height, width), dtype=np.uint8)
        cv2.drawContours(
            contour_mask,
            [contour],
            -1,
            255,
            cv2.FILLED,
        )
        inside = contour_mask > 0

        warm = (
            (
                ((hue >= 5) & (hue <= 40))
                | (hue >= 165)
            )
            & (saturation >= 20)
            & (value >= 30)
        )

        light = (
            (saturation <= 75)
            & (value >= 90)
        )

        warm_ratio = (
            float(np.mean(warm[inside]))
            if np.any(inside)
            else 0.0
        )

        light_ratio = (
            float(np.mean(light[inside]))
            if np.any(inside)
            else 0.0
        )

        onion_tone_ratio = max(warm_ratio, light_ratio)

        shape_ok = (
            aspect <= 2.2
            and circularity >= 0.24
            and solidity >= 0.72
            and extent >= 0.42
        )

        # Do not reject large valid onion groups just because their combined
        # contour covers most of the image.
        size_ok = 0.005 <= area_ratio <= 1.0

        tone_ok = (
            warm_ratio >= 0.12
            or light_ratio >= 0.45
            or red_purple_ratio >= 0.25
        )

        shape_score = float(
            np.clip((circularity - 0.15) / 0.60, 0.0, 1.0)
        )
        solidity_score = float(
            np.clip((solidity - 0.55) / 0.40, 0.0, 1.0)
        )
        tone_score = float(
            np.clip(
                max(onion_tone_ratio, red_purple_ratio) / 0.60,
                0.0,
                1.0,
            )
        )
        area_score = float(
            np.clip(area_ratio / 0.08, 0.0, 1.0)
        )

        candidate_score = (
            0.35 * shape_score
            + 0.25 * solidity_score
            + 0.25 * tone_score
            + 0.15 * area_score
        )

        best_score = max(best_score, candidate_score)

        if shape_ok and size_ok and tone_ok:
            candidates.append(
                {
                    "contour": contour,
                    "score": candidate_score,
                    "bbox": (x, y, w, h),
                    "area_ratio": area_ratio,
                }
            )

    if not candidates:
        return (
            False,
            "The uploaded image does not appear to contain a clearly detectable onion. Please upload a clear onion photo.",
            round(float(np.clip(best_score, 0.0, 1.0)), 2),
        )

    strongest = max(candidates, key=lambda item: item["score"])
    acceptance_score = float(strongest["score"])

    if acceptance_score < 0.52:
        return (
            False,
            "The image is not sufficiently onion-like for reliable assessment. Please upload a clear onion photo.",
            round(float(np.clip(acceptance_score, 0.0, 1.0)), 2),
        )

    return (
        True,
        "Onion image accepted for visual assessment.",
        round(float(np.clip(acceptance_score, 0.0, 1.0)), 2),
    )


# =========================================================
# SHAPE ANALYSIS
# =========================================================

def analyze_shape(
    contours: list,
) -> dict:

    if not contours:

        return {
            "status": "Not detected",
            "uniformity": None,
            "average_circularity": None,
            "object_count": 0,
        }

    circularities = []
    areas = []

    for contour in contours:

        area = cv2.contourArea(
            contour
        )

        perimeter = cv2.arcLength(
            contour,
            True,
        )

        if area <= 0 or perimeter <= 0:
            continue

        circularity = (
            4.0 *
            np.pi *
            area /
            (perimeter * perimeter)
        )

        circularities.append(
            float(
                np.clip(
                    circularity,
                    0.0,
                    1.0,
                )
            )
        )

        areas.append(
            float(area)
        )

    if not circularities:

        return {
            "status": "Not detected",
            "uniformity": None,
            "average_circularity": None,
            "object_count": len(contours),
        }

    uniformity = None

    if (
        len(areas) > 1 and
        np.mean(areas) > 0
    ):

        coefficient_variation = (
            np.std(areas) /
            np.mean(areas)
        )

        uniformity = float(
            np.clip(
                100.0 *
                (1.0 - coefficient_variation),
                0.0,
                100.0,
            )
        )

    return {
        "status": "Detected",
        "uniformity": (
            None
            if uniformity is None
            else round(uniformity, 1)
        ),
        "average_circularity": round(
            float(
                np.mean(circularities)
            ),
            3,
        ),
        "object_count": len(contours),
    }


# =========================================================
# COLOUR ANALYSIS
# =========================================================

def analyze_colour(
    image: np.ndarray,
    mask: np.ndarray,
) -> dict:

    foreground = mask > 0

    if not np.any(foreground):

        return {
            "status": "Not detected",
            "uniformity": None,
            "mean_colour_bgr": None,
        }

    lab = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2LAB,
    )

    lab_pixels = lab[
        foreground
    ].astype(np.float32)

    variation = float(
        np.mean(
            np.std(
                lab_pixels,
                axis=0,
            )
        )
    )

    uniformity = float(
        np.clip(
            100.0 -
            variation * 2.0,
            0.0,
            100.0,
        )
    )

    mean_bgr = np.mean(
        image[foreground],
        axis=0,
    )

    return {
        "status": "Detected",
        "uniformity": round(
            uniformity,
            1,
        ),
        "mean_colour_bgr": [
            round(float(x), 1)
            for x in mean_bgr
        ],
    }


# =========================================================
# VISIBLE DAMAGE ANALYSIS
# =========================================================

def analyze_visible_damage(
    image: np.ndarray,
    mask: np.ndarray,
) -> dict:

    hsv = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2HSV,
    )

    value = hsv[:, :, 2]

    foreground = mask > 0

    total = int(
        np.count_nonzero(
            foreground
        )
    )

    if total == 0:

        return {
            "status": "Not detected",
            "visible_dark_area_percent": None,
            "severity": None,
        }

    dark_pixels = (
        foreground &
        (value < 45)
    )

    dark_percentage = float(
        np.count_nonzero(
            dark_pixels
        ) /
        total *
        100.0
    )

    if dark_percentage < 2.0:
        severity = "Low"

    elif dark_percentage < 7.0:
        severity = "Moderate"

    else:
        severity = "High"

    return {
        "status": "Detected",
        "visible_dark_area_percent": round(
            float(
                np.clip(
                    dark_percentage,
                    0.0,
                    100.0,
                )
            ),
            2,
        ),
        "severity": severity,
    }


# =========================================================
# SPROUTING ANALYSIS
# =========================================================

def analyze_sprouting(
    image: np.ndarray,
    mask: np.ndarray,
) -> dict:

    hsv = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2HSV,
    )

    hue = hsv[:, :, 0]
    saturation = hsv[:, :, 1]
    value = hsv[:, :, 2]

    foreground = mask > 0

    total = int(
        np.count_nonzero(
            foreground
        )
    )

    if total == 0:

        return {
            "status": "Not detected",
            "green_area_percent": None,
            "sprouting_indicator": None,
        }

    green = (
        foreground &
        (hue >= 35) &
        (hue <= 90) &
        (saturation >= 45) &
        (value >= 45)
    )

    green_percentage = float(
        np.count_nonzero(
            green
        ) /
        total *
        100.0
    )

    if green_percentage < 0.5:

        indicator = "Not apparent"

    elif green_percentage < 3.0:

        indicator = "Possible"

    else:

        indicator = "Visible indicator"

    return {
        "status": "Analysed",
        "green_area_percent": round(
            green_percentage,
            2,
        ),
        "sprouting_indicator": indicator,
    }


# =========================================================
# CONFIDENCE
# =========================================================

def calculate_confidence(
    image_info: dict,
    contours: list,
    mask: np.ndarray,
) -> float:

    width = int(
        image_info["width"]
    )

    height = int(
        image_info["height"]
    )

    resolution_score = min(
        1.0,
        (
            width *
            height
        ) /
        float(500 * 500),
    )

    object_score = (
        1.0
        if contours
        else 0.2
    )

    total = (
        mask.shape[0] *
        mask.shape[1]
    )

    ratio = (
        np.count_nonzero(mask) /
        total
        if total
        else 0.0
    )

    if 0.05 <= ratio <= 0.85:

        framing_score = 1.0

    elif ratio > 0:

        framing_score = 0.6

    else:

        framing_score = 0.2

    confidence = (
        resolution_score * 0.35 +
        object_score * 0.35 +
        framing_score * 0.30
    )

    return round(
        float(
            np.clip(
                confidence,
                0.0,
                1.0,
            )
        ),
        2,
    )


# =========================================================
# QUALITY SCORE
# =========================================================

def calculate_quality_score(
    shape_result: dict,
    colour_result: dict,
    damage_result: dict,
    sprouting_result: dict,
):

    components = []

    if shape_result["uniformity"] is not None:

        components.append(
            float(
                shape_result[
                    "uniformity"
                ]
            )
        )

    elif shape_result[
        "average_circularity"
    ] is not None:

        components.append(
            float(
                shape_result[
                    "average_circularity"
                ]
            ) * 100.0
        )

    if colour_result[
        "uniformity"
    ] is not None:

        components.append(
            float(
                colour_result[
                    "uniformity"
                ]
            )
        )

    if damage_result[
        "visible_dark_area_percent"
    ] is not None:

        damage_score = max(
            0.0,
            100.0 -
            float(
                damage_result[
                    "visible_dark_area_percent"
                ]
            ) * 8.0,
        )

        components.append(
            damage_score
        )

    if sprouting_result[
        "green_area_percent"
    ] is not None:

        sprouting_score = max(
            0.0,
            100.0 -
            float(
                sprouting_result[
                    "green_area_percent"
                ]
            ) * 15.0,
        )

        components.append(
            sprouting_score
        )

    if not components:

        return None

    return round(
        float(
            np.clip(
                np.mean(
                    components
                ),
                0.0,
                100.0,
            )
        ),
        1,
    )


# =========================================================
# INDICATIVE VISUAL GRADE
# =========================================================

def determine_visual_grade(
    score,
    damage_result: dict,
    sprouting_result: dict,
) -> str:

    if score is None:

        return "Unable to assess"

    dark = float(
        damage_result[
            "visible_dark_area_percent"
        ] or 0.0
    )

    green = float(
        sprouting_result[
            "green_area_percent"
        ] or 0.0
    )

    if (
        score >= 85.0 and
        dark < 2.0 and
        green < 0.5
    ):

        return "Extra Class"

    if (
        score >= 65.0 and
        dark < 7.0 and
        green < 3.0
    ):

        return "Class I"

    return "Class II"


# =========================================================
# OPTIONAL PHYSICAL SIZE INFORMATION
# =========================================================

def classify_onion_size(average_size_mm: float | None) -> dict:
    """
    Classify the user-provided average equatorial diameter into
    the onion size categories used by the grading/marking standard.

    Important: size category is reported separately from the
    Extra Class / Class I / Class II quality grade. A physical
    diameter alone must not be used to claim a quality grade.
    """
    if average_size_mm is None:
        return {
            "provided": False,
            "average_diameter_mm": None,
            "size_category": None,
            "status": "Not provided",
            "note": "Optional physical onion size was not entered.",
        }

    value = float(average_size_mm)

    if value <= 0:
        raise HTTPException(
            status_code=400,
            detail="Average onion size must be greater than 0 mm.",
        )

    if value < 10:
        category = "Below A"
        range_text = "< 10 mm"
    elif value <= 20:
        category = "A"
        range_text = "10–20 mm"
    elif value <= 40:
        category = "B"
        range_text = "21–40 mm"
    elif value <= 70:
        category = "C"
        range_text = "41–70 mm"
    else:
        category = "D"
        range_text = "71 mm and above"

    return {
        "provided": True,
        "average_diameter_mm": round(value, 1),
        "size_category": category,
        "range": range_text,
        "status": "Provided",
        "note": (
            "Physical size is used as an additional sizing parameter. "
            "It does not by itself determine Extra Class, Class I, or Class II."
        ),
    }


# =========================================================
# SUMMARY
# =========================================================

def create_summary(
    grade: str,
    score,
    confidence: float,
    shape_result: dict,
    damage_result: dict,
    sprouting_result: dict,
    size_result: dict,
) -> str:

    if score is None:

        return (
            "The image did not provide enough visible "
            "information for a reliable visual assessment."
        )

    dark = damage_result[
        "visible_dark_area_percent"
    ]

    green = sprouting_result[
        "green_area_percent"
    ]

    dark_text = (
        "not measurable"
        if dark is None
        else f"{dark:.1f}%"
    )

    green_text = (
        "not measurable"
        if green is None
        else f"{green:.1f}%"
    )

    size_text = "not provided"
    if size_result.get("provided"):
        size_text = (
            f"{size_result['average_diameter_mm']:.1f} mm "
            f"(size category {size_result['size_category']})"
        )

    return (
        f"Indicative visual assessment: {grade}. "
        f"Quality score: {score}/100. "
        f"Detected visible objects: "
        f"{shape_result['object_count']}. "
        f"Visible dark-area indicator: "
        f"{dark_text}; "
        f"sprouting indicator: "
        f"{green_text}; "
        f"average physical size: {size_text}; "
        f"image-analysis confidence: "
        f"{confidence:.0%}."
    )


# =========================================================
# COMPLETE ONION ANALYSIS
# =========================================================

def analyze_onion_image(
    image_path: Path,
    image_info: dict,
    average_size_mm: float | None = None,
) -> dict:

    image = load_cv_image(
        image_path
    )

    mask = create_foreground_mask(
        image
    )

    contours = find_onion_contours(
        mask,
        image.shape,
    )

    is_valid_image, validation_message, validation_confidence = validate_onion_image(
        image,
        mask,
        contours,
    )

    if not is_valid_image:
        return {
            "invalid_image": True,
            "validation_message": validation_message,
            "validation_confidence": validation_confidence,
        }

    shape = analyze_shape(
        contours
    )

    colour = analyze_colour(
        image,
        mask,
    )

    damage = analyze_visible_damage(
        image,
        mask,
    )

    sprouting = analyze_sprouting(
        image,
        mask,
    )

    confidence = calculate_confidence(
        image_info,
        contours,
        mask,
    )

    score = calculate_quality_score(
        shape,
        colour,
        damage,
        sprouting,
    )

    grade = determine_visual_grade(
        score,
        damage,
        sprouting,
    )

    size_result = classify_onion_size(average_size_mm)

    return {
        "invalid_image": False,
        "validation_message": validation_message,
        "validation_confidence": validation_confidence,
        "analysis_type": (
            "Computer-vision based "
            "indicative visual assessment"
        ),

        "grade": grade,

        "quality_score": score,

        "confidence": confidence,

        "parameters": {

            "visible_onions": {
                "count": shape[
                    "object_count"
                ],
                "status": shape[
                    "status"
                ],
            },

            "shape": {
                "status": shape[
                    "status"
                ],
                "average_circularity":
                    shape[
                        "average_circularity"
                    ],
                "size_uniformity":
                    shape[
                        "uniformity"
                    ],
            },

            "physical_size": size_result,

            "colour_uniformity": {
                "status": colour[
                    "status"
                ],
                "score": colour[
                    "uniformity"
                ],
            },

            "visible_defects": {
                "status": damage[
                    "status"
                ],
                "dark_area_percent":
                    damage[
                        "visible_dark_area_percent"
                    ],
                "severity": damage[
                    "severity"
                ],
            },

            "sprouting": {
                "status": sprouting[
                    "status"
                ],
                "green_area_percent":
                    sprouting[
                        "green_area_percent"
                    ],
                "indicator":
                    sprouting[
                        "sprouting_indicator"
                    ],
            },

            "cleanliness": {
                "status":
                    "Image-based estimation only",
                "note": (
                    "Reliable cleanliness assessment "
                    "requires controlled image capture."
                ),
            },

            "firmness": {
                "status":
                    "Not assessable from image",
            },

            "internal_defects": {
                "status":
                    "Not assessable from image",
            },
        },

        "summary": create_summary(
            grade,
            score,
            confidence,
            shape,
            damage,
            sprouting,
            size_result,
        ),

        "limitations": [

            "This is an indicative image-based "
            "assessment, not official AGMARK certification.",

            "Firmness cannot be reliably confirmed "
            "from an external photograph.",

            "Internal rot and other internal defects "
            "cannot be reliably confirmed from an "
            "external photograph.",

            "Lighting, camera angle, background, "
            "and image quality can affect the result.",

            "Visible dark regions may include shadows "
            "or natural onion features.",

            "The grading thresholds in this MVP are "
            "heuristic and must be validated with "
            "labelled onion samples before "
            "operational use.",

            "Physical size is user-provided and is "
            "reported as a separate sizing parameter; "
            "it does not by itself determine the "
            "quality grade.",

            "Clearly unrelated or insufficiently clear images are rejected by an image-validation gate before grading.",
        ],
    }


# =========================================================
# API ENDPOINT
# =========================================================

@app.post("/api/v1/assess-onion")
async def assess_onion(
    file: UploadFile = File(...),
    average_size_mm: float | None = Form(default=None),
):

    if average_size_mm is not None:
        if average_size_mm <= 0 or average_size_mm > 300:
            raise HTTPException(
                status_code=400,
                detail="Average onion size must be between 0 and 300 mm.",
            )

    image_bytes = await validate_image(
        file
    )

    assessment_id = (
        f"FM-ONION-{uuid4().hex[:8].upper()}"
    )

    extension = Path(
        file.filename
    ).suffix.lower()

    image_path = (
        UPLOAD_DIR /
        f"{assessment_id}{extension}"
    )

    try:

        image_path.write_bytes(
            image_bytes
        )

        image_info = read_image_info(
            image_path
        )

        assessment = analyze_onion_image(
            image_path,
            image_info,
            average_size_mm,
        )

        if assessment.get("invalid_image"):
            return {
                "success": False,
                "valid_image": False,
                "error_type": "INVALID_IMAGE",
                "assessment_id": assessment_id,
                "filename": file.filename,
                "message": assessment["validation_message"],
                "validation_confidence": assessment["validation_confidence"],
                "image": image_info,
                "assessment": None,
            }

    except HTTPException:

        raise

    except Exception as exc:

        raise HTTPException(
            status_code=500,
            detail=(
                f"Image analysis failed: {exc}"
            ),
        )

    return {
        "success": True,
        "valid_image": True,
        "assessment_id": assessment_id,
        "filename": file.filename,
        "input": {
            "average_size_mm": (
                None
                if average_size_mm is None
                else round(float(average_size_mm), 1)
            ),
        },
        "image": image_info,
        "assessment": assessment,
    }


# =========================================================
# RUN DIRECTLY
# =========================================================

if __name__ == "__main__":

    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
