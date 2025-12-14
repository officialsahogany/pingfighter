"""
누끼 따기 프로그램 (Background Remover)
rembg AI 기반 자동 배경 제거
"""

import os
import sys
from pathlib import Path

# PyInstaller 환경 설정
def get_base_path():
    """PyInstaller 빌드 환경에서 기본 경로 반환"""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS)
    return Path(__file__).parent

# 모델 경로 설정 (패키징 환경용)
BASE_PATH = get_base_path()
U2NET_HOME = BASE_PATH / '.u2net'
if U2NET_HOME.exists():
    os.environ['U2NET_HOME'] = str(U2NET_HOME)

# GUI imports
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from PIL import Image, ImageTk
import threading

# rembg import
REMBG_AVAILABLE = False
REMBG_ERROR = ""
try:
    from rembg import remove, new_session
    REMBG_AVAILABLE = True
except ImportError as e:
    REMBG_ERROR = str(e)
except Exception as e:
    REMBG_ERROR = str(e)


class BackgroundRemoverApp:
    def __init__(self, root):
        self.root = root
        self.root.title("누끼 따기 (Background Remover)")
        self.root.geometry("1000x700")
        self.root.minsize(800, 600)

        # 상태 변수
        self.original_image = None
        self.result_image = None
        self.current_file = None
        self.processing = False
        self.session = None  # rembg 세션 (성능 향상)

        # UI 설정
        self.setup_ui()

        # rembg 체크
        if not REMBG_AVAILABLE:
            messagebox.showerror(
                "오류",
                f"rembg를 로드할 수 없습니다.\n\n"
                f"오류: {REMBG_ERROR}\n\n"
                "터미널에서 다음 명령을 실행하세요:\n"
                "pip install rembg onnxruntime Pillow"
            )

    def setup_ui(self):
        """UI 구성"""
        # 메인 프레임
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.pack(fill=tk.BOTH, expand=True)

        # 상단 버튼 영역
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Button(
            button_frame,
            text="📂 이미지 열기",
            command=self.open_image
        ).pack(side=tk.LEFT, padx=5)

        ttk.Button(
            button_frame,
            text="📁 폴더 열기 (일괄 처리)",
            command=self.open_folder
        ).pack(side=tk.LEFT, padx=5)

        self.process_btn = ttk.Button(
            button_frame,
            text="✨ 누끼 따기",
            command=self.process_image,
            state=tk.DISABLED
        )
        self.process_btn.pack(side=tk.LEFT, padx=5)

        self.save_btn = ttk.Button(
            button_frame,
            text="💾 저장",
            command=self.save_image,
            state=tk.DISABLED
        )
        self.save_btn.pack(side=tk.LEFT, padx=5)

        # 모드 선택
        ttk.Label(button_frame, text="모드:").pack(side=tk.LEFT, padx=(20, 5))
        self.mode_var = tk.StringVar(value="ai")
        mode_combo = ttk.Combobox(
            button_frame,
            textvariable=self.mode_var,
            values=["ai", "체커보드 제거", "색상 선택"],
            state="readonly",
            width=12
        )
        mode_combo.pack(side=tk.LEFT)

        # 모델 선택 (AI 모드용)
        ttk.Label(button_frame, text="AI모델:").pack(side=tk.LEFT, padx=(10, 5))
        self.model_var = tk.StringVar(value="isnet-general-use")
        self.model_combo = ttk.Combobox(
            button_frame,
            textvariable=self.model_var,
            values=["isnet-general-use", "u2net", "u2netp", "u2net_human_seg", "silueta"],
            state="readonly",
            width=16
        )
        self.model_combo.pack(side=tk.LEFT)
        self.model_combo.bind("<<ComboboxSelected>>", self.on_model_change)

        # 이미지 표시 영역
        image_frame = ttk.Frame(main_frame)
        image_frame.pack(fill=tk.BOTH, expand=True)

        # 원본 이미지
        left_frame = ttk.LabelFrame(image_frame, text="원본", padding="5")
        left_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 5))

        self.original_canvas = tk.Canvas(left_frame, bg="#2b2b2b")
        self.original_canvas.pack(fill=tk.BOTH, expand=True)

        # 결과 이미지
        right_frame = ttk.LabelFrame(image_frame, text="결과 (투명 배경)", padding="5")
        right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=(5, 0))

        self.result_canvas = tk.Canvas(right_frame, bg="#2b2b2b")
        self.result_canvas.pack(fill=tk.BOTH, expand=True)

        # 체커보드 패턴 그리기 (투명 배경 표시용)
        self.draw_checkerboard(self.result_canvas)

        # 상태바
        self.status_var = tk.StringVar(value="이미지를 열어주세요")
        status_bar = ttk.Label(
            main_frame,
            textvariable=self.status_var,
            relief=tk.SUNKEN,
            padding="5"
        )
        status_bar.pack(fill=tk.X, pady=(10, 0))

        # 프로그레스 바
        self.progress = ttk.Progressbar(main_frame, mode='indeterminate')
        self.progress.pack(fill=tk.X, pady=(5, 0))

        # 드래그 앤 드롭 바인딩 (tkinterdnd2가 있는 경우)
        try:
            from tkinterdnd2 import DND_FILES
            self.root.drop_target_register(DND_FILES)
            self.root.dnd_bind('<<Drop>>', self.on_drop)
        except ImportError:
            pass

    def draw_checkerboard(self, canvas, size=10):
        """투명 배경 표시용 체커보드 패턴"""
        canvas.delete("checkerboard")
        w = canvas.winfo_width() or 400
        h = canvas.winfo_height() or 400

        for i in range(0, w, size):
            for j in range(0, h, size):
                color = "#404040" if (i // size + j // size) % 2 == 0 else "#505050"
                canvas.create_rectangle(
                    i, j, i + size, j + size,
                    fill=color, outline="", tags="checkerboard"
                )

    def on_drop(self, event):
        """드래그 앤 드롭 처리"""
        file_path = event.data.strip('{}')
        if file_path.lower().endswith(('.png', '.jpg', '.jpeg', '.webp', '.bmp')):
            self.load_image(file_path)

    def open_image(self):
        """이미지 파일 열기"""
        file_path = filedialog.askopenfilename(
            title="이미지 선택",
            filetypes=[
                ("이미지 파일", "*.png *.jpg *.jpeg *.webp *.bmp"),
                ("모든 파일", "*.*")
            ]
        )
        if file_path:
            self.load_image(file_path)

    def open_folder(self):
        """폴더 열어서 일괄 처리"""
        folder_path = filedialog.askdirectory(title="이미지 폴더 선택")
        if folder_path:
            self.batch_process(folder_path)

    def load_image(self, file_path):
        """이미지 로드"""
        try:
            self.current_file = file_path
            self.original_image = Image.open(file_path).convert("RGBA")
            self.result_image = None

            # 캔버스에 표시
            self.display_image(self.original_canvas, self.original_image)
            self.result_canvas.delete("image")
            self.draw_checkerboard(self.result_canvas)

            # 버튼 상태 업데이트
            self.process_btn.config(state=tk.NORMAL)
            self.save_btn.config(state=tk.DISABLED)

            self.status_var.set(f"로드됨: {os.path.basename(file_path)} ({self.original_image.size[0]}x{self.original_image.size[1]})")

        except Exception as e:
            messagebox.showerror("오류", f"이미지를 열 수 없습니다:\n{e}")

    def display_image(self, canvas, image, max_size=450):
        """캔버스에 이미지 표시"""
        canvas.delete("image")

        # 캔버스 크기에 맞게 리사이즈
        canvas.update()
        canvas_w = canvas.winfo_width() or max_size
        canvas_h = canvas.winfo_height() or max_size

        # 비율 유지하며 리사이즈
        img_w, img_h = image.size
        ratio = min(canvas_w / img_w, canvas_h / img_h, 1.0)
        new_size = (int(img_w * ratio), int(img_h * ratio))

        display_img = image.copy()
        display_img.thumbnail(new_size, Image.Resampling.LANCZOS)

        # PhotoImage로 변환
        photo = ImageTk.PhotoImage(display_img)
        canvas.image = photo  # 참조 유지

        # 중앙에 배치
        x = canvas_w // 2
        y = canvas_h // 2
        canvas.create_image(x, y, image=photo, anchor=tk.CENTER, tags="image")

    def on_model_change(self, event=None):
        """모델 변경시 세션 초기화"""
        self.session = None

    def process_image(self):
        """배경 제거 처리"""
        if self.original_image is None or self.processing:
            return

        if not REMBG_AVAILABLE:
            messagebox.showerror("오류", "rembg가 설치되지 않았습니다.")
            return

        self.processing = True
        self.process_btn.config(state=tk.DISABLED)
        self.progress.start(10)
        self.status_var.set("처리 중... (첫 실행시 모델 다운로드로 시간이 걸릴 수 있습니다)")

        # 별도 스레드에서 처리
        thread = threading.Thread(target=self._process_thread)
        thread.daemon = True
        thread.start()

    def _process_thread(self):
        """백그라운드 처리 스레드"""
        try:
            mode = self.mode_var.get()

            if mode == "체커보드 제거":
                # 체커보드 패턴 배경 제거 (회색 계열)
                result = self._remove_checkerboard_bg(self.original_image)
            elif mode == "색상 선택":
                # 특정 색상 범위 제거 (체커보드 회색 기본값)
                result = self._remove_color_range(self.original_image)
            else:
                # AI 모드
                model_name = self.model_var.get()

                # 세션 생성 (재사용)
                if self.session is None:
                    self.session = new_session(model_name)

                # 배경 제거 (alpha matting 없이)
                result = remove(
                    self.original_image,
                    session=self.session,
                    alpha_matting=False,
                )

            self.result_image = result

            # UI 업데이트 (메인 스레드에서)
            self.root.after(0, self._process_complete)

        except Exception as e:
            self.root.after(0, lambda: self._process_error(str(e)))

    def _remove_checkerboard_bg(self, image):
        """체커보드 배경 제거 (회색 계열 픽셀을 투명하게)"""
        import numpy as np

        img_array = np.array(image.convert("RGBA"))
        r, g, b, a = img_array[:,:,0], img_array[:,:,1], img_array[:,:,2], img_array[:,:,3]

        # 체커보드 색상 감지 (회색 계열: R≈G≈B, 밝기 범위)
        # 일반적인 체커보드: 밝은 회색(~200) + 어두운 회색(~150)
        gray_tolerance = 15  # R, G, B 차이 허용 범위
        is_gray = (np.abs(r.astype(int) - g.astype(int)) < gray_tolerance) & \
                  (np.abs(g.astype(int) - b.astype(int)) < gray_tolerance) & \
                  (np.abs(r.astype(int) - b.astype(int)) < gray_tolerance)

        # 체커보드 밝기 범위 (보통 100~220 사이의 회색)
        brightness = (r.astype(int) + g.astype(int) + b.astype(int)) / 3
        is_checkerboard_brightness = (brightness > 100) & (brightness < 230)

        # 회색이면서 체커보드 밝기 범위인 픽셀을 투명하게
        mask = is_gray & is_checkerboard_brightness

        # 투명하게 만들기
        img_array[mask, 3] = 0

        return Image.fromarray(img_array)

    def _remove_color_range(self, image):
        """색상 범위로 배경 제거 (체커보드/단색 배경용)"""
        import numpy as np

        img_array = np.array(image.convert("RGBA"))
        r, g, b, a = img_array[:,:,0], img_array[:,:,1], img_array[:,:,2], img_array[:,:,3]

        # 회색 계열 + 흰색 + 검은색 배경 제거
        gray_tolerance = 20
        is_gray = (np.abs(r.astype(int) - g.astype(int)) < gray_tolerance) & \
                  (np.abs(g.astype(int) - b.astype(int)) < gray_tolerance)

        # 순수 흰색/검은색도 제거
        brightness = (r.astype(int) + g.astype(int) + b.astype(int)) / 3
        is_white = brightness > 240
        is_black = brightness < 15
        is_mid_gray = (brightness > 80) & (brightness < 220) & is_gray

        # 배경으로 판단되는 픽셀 투명화
        mask = is_white | is_black | is_mid_gray
        img_array[mask, 3] = 0

        return Image.fromarray(img_array)

    def _process_complete(self):
        """처리 완료"""
        self.processing = False
        self.progress.stop()
        self.process_btn.config(state=tk.NORMAL)
        self.save_btn.config(state=tk.NORMAL)

        # 결과 표시
        self.draw_checkerboard(self.result_canvas)
        self.display_image(self.result_canvas, self.result_image)

        self.status_var.set("✅ 처리 완료! 저장 버튼을 눌러 저장하세요.")

    def _process_error(self, error_msg):
        """처리 오류"""
        self.processing = False
        self.progress.stop()
        self.process_btn.config(state=tk.NORMAL)
        self.status_var.set(f"❌ 오류 발생: {error_msg}")
        messagebox.showerror("처리 오류", f"배경 제거 중 오류 발생:\n{error_msg}")

    def save_image(self):
        """결과 이미지 저장"""
        if self.result_image is None:
            return

        # 기본 파일명 생성
        if self.current_file:
            base_name = os.path.splitext(os.path.basename(self.current_file))[0]
            default_name = f"{base_name}_nobg.png"
        else:
            default_name = "result_nobg.png"

        file_path = filedialog.asksaveasfilename(
            title="저장",
            defaultextension=".png",
            initialfile=default_name,
            filetypes=[("PNG 파일", "*.png")]
        )

        if file_path:
            try:
                self.result_image.save(file_path, "PNG")
                self.status_var.set(f"✅ 저장됨: {file_path}")
                messagebox.showinfo("저장 완료", f"저장되었습니다:\n{file_path}")
            except Exception as e:
                messagebox.showerror("저장 오류", f"저장 중 오류 발생:\n{e}")

    def batch_process(self, folder_path):
        """폴더 내 모든 이미지 일괄 처리"""
        if not REMBG_AVAILABLE:
            messagebox.showerror("오류", "rembg가 설치되지 않았습니다.")
            return

        # 이미지 파일 찾기
        image_files = []
        for ext in ('*.png', '*.jpg', '*.jpeg', '*.webp', '*.bmp'):
            image_files.extend(Path(folder_path).glob(ext))
            image_files.extend(Path(folder_path).glob(ext.upper()))

        if not image_files:
            messagebox.showwarning("알림", "폴더에 이미지 파일이 없습니다.")
            return

        # 출력 폴더 생성
        output_folder = Path(folder_path) / "nobg_output"
        output_folder.mkdir(exist_ok=True)

        # 확인
        result = messagebox.askyesno(
            "일괄 처리",
            f"{len(image_files)}개의 이미지를 처리합니다.\n\n"
            f"출력 폴더: {output_folder}\n\n"
            "계속하시겠습니까?"
        )

        if not result:
            return

        self.processing = True
        self.process_btn.config(state=tk.DISABLED)
        self.progress.start(10)

        # 별도 스레드에서 일괄 처리
        thread = threading.Thread(
            target=self._batch_thread,
            args=(image_files, output_folder)
        )
        thread.daemon = True
        thread.start()

    def _batch_thread(self, image_files, output_folder):
        """일괄 처리 스레드"""
        try:
            model_name = self.model_var.get()
            if self.session is None:
                self.session = new_session(model_name)

            total = len(image_files)
            success = 0

            for i, file_path in enumerate(image_files):
                self.root.after(0, lambda f=file_path, n=i+1, t=total:
                    self.status_var.set(f"처리 중 ({n}/{t}): {f.name}"))

                try:
                    # 이미지 로드 및 처리
                    img = Image.open(file_path).convert("RGBA")
                    result = remove(img, session=self.session)

                    # 저장
                    output_path = output_folder / f"{file_path.stem}_nobg.png"
                    result.save(output_path, "PNG")
                    success += 1

                except Exception as e:
                    print(f"Error processing {file_path}: {e}")

            self.root.after(0, lambda: self._batch_complete(success, total, output_folder))

        except Exception as e:
            self.root.after(0, lambda: self._process_error(str(e)))

    def _batch_complete(self, success, total, output_folder):
        """일괄 처리 완료"""
        self.processing = False
        self.progress.stop()
        self.process_btn.config(state=tk.NORMAL)

        self.status_var.set(f"✅ 일괄 처리 완료: {success}/{total}개 성공")
        messagebox.showinfo(
            "일괄 처리 완료",
            f"처리 완료!\n\n"
            f"성공: {success}/{total}개\n"
            f"출력 폴더: {output_folder}"
        )


def main():
    root = tk.Tk()

    # 스타일 설정
    style = ttk.Style()
    style.theme_use('clam')

    app = BackgroundRemoverApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
