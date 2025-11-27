# downtown/npc.py
# 번화가 NPC 시스템 - 주민, 로봇, 강아지, 고양이 등

import pygame
import pygame.freetype
import math
import random
import os
from .constants import (
    TILE_SIZE, SCREEN_WIDTH, SCREEN_HEIGHT,
    MAP_WIDTH, MAP_HEIGHT, Colors, TileType,
    resource_path
)


class NPCType:
    """NPC 타입 정의"""
    CITIZEN_MALE = "citizen_male"
    CITIZEN_FEMALE = "citizen_female"
    ROBOT = "robot"
    DOG = "dog"
    CAT = "cat"
    CHILD = "child"
    OLD_MAN = "old_man"
    MERCHANT = "merchant"


# ============================================================================
# NPC 대화 데이터베이스
# ============================================================================
NPC_DIALOGUES = {
    # 게임 팁 관련 대화
    "game_tips": [
        "대쉬 손맛이 짜릿해서 핑파이터를 못끊겠어.",
        "빨간색 이름으로 된 옵션이 가장 좋다고 하더군.",
        "스테이지4에서 연막탄을 쓰면 조상들이 도와준다는 전설이 있네.",
        "코만도의 그물덫총으로 포획 한 후 좌우 연타를 하면 그물이 조여진대.",
        "보스가 패턴을 바꾸기 직전에 대쉬하면 회피가 쉬워.",
        "아이템을 잘 조합하면 시너지 효과가 엄청나더라.",
        "전투도중 가끔 노란색 별이 떨어지니까 놓치지 마. 그거 다 돈이야",
        "전설 아이템은 운이 좋아야 얻을 수 있대.",
        "스매셔는 단순하지만 강력해.",
        "스테이지 클리어 시간이 빠를수록 보상이 좋다던데.",
        "게임 도중 연막탄을 쓰면 위험한 스킬로부터 보호할 수 있어.",
        "TAB키를 누르면 내 정보를 확인할 수 있지.",
        "코만도 무기중에 자폭드론이 제일 무섭더라. 직접 조종이라니...",
        "보스 패턴을 외우면 클리어가 훨씬 쉬워져.",
        "속도 스탯에 올인하면 방어와 회피가 쉬워.",
        "수류탄으로 보스를 바보만들 때 짜릿한 쾌감을 느끼지.",
        "가챠에서 전설아이템이 나왔어 가보로 물려줄려고",
        "위험감지센서 이 아이템은 아무리 생각해도 사기인거같아 그냥 전설급인듯",
        "액티브 스킬은 쿨타임 관리가 핵심이야.",
        "효과음 볼륨을 따로 조절하면 집중하기 좋아.",
        "튜토리얼 모드를 다시 해보는 것도 도움 돼.",
        "멘탈 관리도 실력이야.",
        "게임이 잘안되는 날은 잠깐 쉬는 게 좋아.",
        "컨디션 난조일 땐 무리하지 마.",
        "즐기는 게 제일 중요해.",
    ],

    # 세계관 관련 대화
    "world_lore": [
        "내 원래 몸은 지구에 있어. 여긴 가상현실이지.",
        "이 행성의 중력이 지구랑 달라서 공이 이상하게 움직여.",
        "여기 있는 건물들은 전부 데이터로 이루어져 있대.",
        "행성마다 분위기가 다른 건 테마 설정 때문이래.",
        "콜로세움에서는 매일 치열한 경기가 열린다더군.",
        "이 세계에서 죽어도 리스폰되니까 걱정 마.",
        "대장장이 기술은 고대 AI 문명에서 전해진 거래.",
        "도박장은 확률 조작이 없다고 관리자가 보증했어.",
        "이 번화가는 스테이지 사이에 있는 안식처야.",
        "가상현실이라도 여기서 느끼는 감정은 진짜야.",
        "이 세계는 누가 만든 걸까? 신? 아니면 프로그래머?",
        "다른 차원에서 온 선수들도 있다던데.",
        "시간의 흐름이 현실과 다르다는 걸 알아?",
        "여기선 24시간이 현실의 1시간이래.",
        "가끔 현실과 가상을 헷갈릴 때가 있어.",
        "과거에 광장 서버가 다운된 적도 있대.",
        "건강을 위해 2시간마다 휴식하래.",
        "이 세계의 역사는 100년이 넘었대.",
        "현실에선 위험한 걸 여기선 안전하게 체험해.",
        "이 세계의 경제 시스템도 복잡해.",
        "환율도 실시간으로 변해.",
        "이 세계의 미래는 어떻게 될까? 더 발전할까? 아니면 쇠퇴할까?",
        "더 나은 세상을 위해 노력하자.",
    ],

    # 일상 대화
    "daily_life": [
        "날씨가 좋네. 오늘도 좋은 하루 보내.",
        "요즘 번화가에 사람이 많아졌어.",
        "나도 예전엔 핑파이터 선수였지...",
        "오늘 상점에서 세일한다던데 확인해봤어?",
        "피곤해. 오늘 하루가 너무 길었어.",
        "저기 지나가는 로봇 봤어? 신기하지?",
        "이 근처에 맛집이 있는데 알려줄까?",
        "운동 좀 해야 하는데 귀찮아서...",
        "요즘 젊은 선수들 실력이 대단하더라.",
        "가끔은 지구가 그리워.",
        "오늘 날씨 좋다. 낚시나 하러갈까.",
        "나도 전설 아이템 가지고 싶다...",
        "나도 너처럼 강해지고 싶어.",
        "아침에 커피 마시는 게 낙이야.",
        "점심은 뭐 먹지? 고민되네.",
        "저녁엔 친구들 만나기로 했어.",
        "주말엔 뭐하지? 계획 없어.",
        "휴가 가고 싶다. 어디로 갈까?",
        "돈 좀 벌어야 하는데 방법이 없네.",
        "복권 당첨되면 일 안 할 텐데.",
        "열심히 일해도 돈이 안 모여.",
        "물가가 너무 올라서 힘들어.",
        "집값은 언제 내려가려나.",
        "차는 언제 사지? 당분간 힘들겠어.",
        "결혼 자금 모으기 빡세네.",
        "애들 키우는 건 돈이 엄청 들래.",
        "요즘 젊은이들 힘들어.",
        "우리 때보다 경쟁이 치열해.",
        "그래도 희망은 있어.",
        "열심히 하면 길이 보여.",
        "포기하면 거기서 끝이야.",
        "도전하는 게 중요해.",
        "실패해도 괜찮아. 배우는 거니까.",
        "경험이 쌓이면 성장하는 거야.",
        "오늘보다 나은 내일을 만들자.",
        "건강이 제일 중요해. 몸 챙겨.",
        "잠 좀 자. 무리하지 마.",
        "스트레스 풀 방법을 찾아봐.",
        "취미 생활이 도움 돼.",
        "음악 들으면 기분 전환 돼.",
        "운동하면 스트레스가 풀려.",
        "산책만 해도 머리가 맑아져.",
        "자연이 주는 치유력은 대단해.",
        "가끔 하늘 좀 봐. 아름다워.",
        "별을 세는 것도 낭만적이야.",
        "달빛 아래 걷는 것도 좋아.",
        "밤공기가 시원해.",
        "새벽 공기는 또 달라.",
        "아침 햇살을 받으면 활력이 생겨.",
        "일출을 보면 감동적이야.",
        "일몰도 아름다워.",
        "노을 지는 하늘은 예술이야.",
        "사진 찍기 좋은 시간이지.",
        "추억을 남겨두는 것도 중요해.",
        "훗날 보면 그때가 그리워.",
        "시간은 빨리 흘러.",
        "하루하루 소중히 살자.",
        "후회 없이 살고 싶어.",
        "의미 있는 일을 하고 싶어.",
        "누군가에게 도움이 되고 싶어.",
        "세상을 조금이라도 좋게 만들고 싶어.",
        "작은 선행이 모여 큰 변화를 만들어.",
        "친절은 전염돼. 좋은 영향을 퍼뜨려.",
        "웃음도 전염돼. 많이 웃자.",
        "긍정적인 마인드가 중요해.",
        "부정적인 생각은 멀리해.",
        "감사하는 마음을 가지자.",
        "가진 것에 만족하는 법을 배워.",
        "비교하지 마. 내 길을 가.",
        "남의 시선은 신경 쓰지 마.",
        "내가 행복하면 그게 성공이야.",
        "돈이 전부는 아니야.",
        "사랑하는 사람들과 함께 있는 게 행복이야.",
        "가족이 제일 소중해.",
        "친구도 재산이야.",
        "인연을 소중히 해.",
        "만남에 감사하고 이별을 받아들여.",
        "모든 것은 지나가.",
        "힘든 시간도 언젠가 추억이 돼.",
        "지금 이 순간도 소중해.",
        "현재를 살자. 과거와 미래에 얽매이지 말고.",
        "지금 여기, 이 순간에 집중해.",
        "마음챙김이 평온을 가져다줘.",
        "명상도 좋은 습관이야.",
        "호흡에 집중하면 마음이 차분해져.",
        "요가도 몸과 마음에 좋아.",
        "꾸준한 운동이 답이야.",
        "습관이 인생을 바꿔.",
        "작은 실천이 모여 큰 성과를 만들어.",
        "오늘 하루도 수고했어.",
        "내일은 더 좋은 날이 올 거야.",
        "항상 응원할게.",
    ],

    # 어린이 전용 대화
    "child": [
        "나도 커서 핑파이터가 될 거야!",
        "아저씨 진짜 강해 보여요!",
        "엄마가 늦게까지 놀면 안 된대...",
        "저 강아지 귀엽지 않아요?",
        "숨바꼭질하자!",
        "나 대쉬하는 법 알아! 휙!",
        "나도 전설 아이템 갖고 싶어요!",
        "나는 롤링 대쉬 10번 연속 성공했어요!",
        "저번에 보스 혼자 잡았어요! 진짜에요!",
        "아빠가 핑파이터 챔피언이래요!",
        "나 생일선물로 새 패들 받았어요!",
        "친구랑 같이 하면 더 재미있어요!",
        "학교에서 핑파이터 대회 열려요!",
        "나 1등 할 거예요! 열심히 연습했거든요!",
        "오늘 숙제 다 했어요! 이제 놀아도 돼요!",
        "형아는 레벨 50이래요! 대박!",
        "누나는 전설 스킨 가지고 있어요! 부러워...",
        "나도 빨리 크고 싶어요!",
        "어른이 되면 매일 게임만 할 거예요!",
        "...엄마한테는 비밀이에요.",
        "아이스크림 먹고 싶어요!",
        "저기 로봇 무섭게 생겼어요...",
        "고양이 쓰다듬어도 돼요?",
        "강아지가 꼬리 흔들어요! 귀여워!",
        "나 달리기 진짜 빨라요! 보여드릴까요?",
        "술래잡기 하실래요?",
        "가위바위보 할까요?",
        "나 마술 보여줄까요? 동전이 사라져요!",
        "숫자 맞히기 게임 해요!",
        "나 퀴즈 잘 맞혀요!",
        "만화 보는 거 좋아해요!",
        "로봇 만화가 제일 재미있어요!",
        "슈퍼히어로 되고 싶어요!",
        "투명인간 되면 뭐 할 거예요?",
        "하늘을 날 수 있으면 좋겠어요!",
        "바다 밑에 가보고 싶어요!",
        "우주에도 가보고 싶어요!",
        "외계인은 진짜 있을까요?",
        "공룡 봤으면 좋겠어요!",
        "타임머신 타고 싶어요!",
        "미래는 어떻게 생겼을까요?",
        "로봇 친구 있으면 좋겠어요!",
        "나중에 과학자 될래요!",
        "발명품 만들 거예요!",
        "세상을 구할 거예요!",
        "영웅이 될 거예요!",
        "나쁜 사람들 혼내줄 거예요!",
        "정의의 편이에요!",
        "친구들 도와주는 거 좋아해요!",
        "착한 일 하면 기분 좋아요!",
        "엄마 아빠 사랑해요!",
        "선생님도 좋아요!",
        "친구들이랑 노는 게 제일 좋아요!",
    ],

    # 노인 전용 대화
    "old_man": [
        "요즘 젊은이들은 참 대단해...",
        "내 젊었을 때도 핑파이터를 했지.",
        "허리가 아파서 오래 서있기 힘들구나.",
        "세월이 참 빠르구나.",
        "건강이 제일 중요한 거야.",
        "옛날엔 이런 가상현실이 없었는데...",
        "60년 전에는 흑백 화면이었지.",
        "그때도 재미있었어.",
        "지금 젊은이들은 행복한 시대를 사네.",
        "기술 발전이 참 놀라워.",
        "내가 어렸을 땐 컴퓨터도 없었어.",
        "손으로 편지 쓰던 시절이었지.",
        "지금은 버튼만 누르면 다 돼.",
        "편해졌지만 뭔가 아쉬운 것도 있어.",
        "느린 것도 나름의 멋이 있거든.",
        "천천히 사는 법을 배워야 해.",
        "빨리만 가는 게 능사가 아니야.",
        "중요한 건 방향이지.",
        "어디로 가는지가 속도보다 중요해.",
        "인생은 마라톤이야. 단거리가 아니라.",
        "꾸준함이 이기는 거야.",
        "조급해하지 마.",
        "때가 되면 다 이루어져.",
        "기다릴 줄도 알아야 해.",
        "인내는 쓰지만 열매는 달아.",
        "경험이 쌓이면 지혜가 생겨.",
        "실수는 누구나 해. 중요한 건 배우는 거야.",
        "같은 실수를 반복하지 않으면 돼.",
        "넘어져도 일어나면 돼.",
        "포기하지 않는 게 중요해.",
        "끝까지 가봐야 알아.",
        "중간에 그만두면 후회해.",
        "다 해보고 후회하는 게 낫지.",
        "안 해보고 후회하는 것보다.",
        "도전하는 용기를 가져.",
        "나이는 숫자일 뿐이야.",
        "마음이 늙지 않으면 젊은 거야.",
        "호기심을 잃지 마.",
        "새로운 것을 배우는 걸 두려워하지 마.",
        "나도 이 나이에 가상현실을 배웠어.",
        "처음엔 어려웠지만 지금은 익숙해.",
        "배우고 싶다는 의지만 있으면 돼.",
        "늙어서도 배울 게 많아.",
        "인생은 평생 배움의 연속이야.",
        "겸손하게 살아야 해.",
        "아는 척하면 더 이상 배울 수 없어.",
        "귀 기울여 들어봐.",
        "누구에게나 배울 점이 있어.",
        "젊은이들한테도 배울 게 많아.",
        "세대 차이는 있지만 서로 존중하면 돼.",
        "소통이 중요해.",
        "말을 아끼고 경청해.",
        "듣는 게 말하는 것보다 중요할 때가 많아.",
        "이해하려고 노력해.",
        "판단하기 전에 이해해봐.",
        "모든 사람은 사연이 있어.",
        "겉모습만 보고 판단하지 마.",
        "진심을 보는 눈을 길러.",
        "사람을 보는 눈이 생기면 인생이 편해.",
        "좋은 사람들과 함께 해.",
        "나쁜 사람은 멀리해.",
        "인연은 소중히 하되 집착하지 마.",
        "떠날 사람은 보내줘야 해.",
        "억지로 붙잡으면 서로 힘들어.",
        "자연스러움이 최고야.",
        "욕심을 줄여.",
        "적게 가지면 마음이 가벼워.",
        "많이 가졌다고 행복한 건 아니야.",
        "행복은 마음먹기에 달렸어.",
        "감사할 줄 알면 행복해.",
        "불평하면 불행해져.",
        "긍정적으로 생각하는 습관을 길러.",
        "유머 감각도 중요해.",
        "웃으면서 살아야 해.",
        "스트레스는 웃음으로 날려.",
        "화내지 마. 건강에 안 좋아.",
        "평정심을 유지해.",
        "화는 참지 말고 다스려.",
        "감정을 억누르는 건 해로워.",
        "건강하게 표현하는 법을 배워.",
        "운동은 꾸준히 해.",
        "나이 들수록 운동이 중요해.",
        "근력을 유지해야 해.",
        "유연성도 중요하고.",
        "스트레칭은 매일 해.",
        "식사는 규칙적으로 해.",
        "과식하지 마.",
        "소식이 장수의 비결이야.",
        "채소를 많이 먹어.",
        "물도 충분히 마셔.",
        "술, 담배는 멀리해.",
        "수면도 중요해.",
        "푹 자야 건강해.",
        "일찍 자고 일찍 일어나.",
        "규칙적인 생활이 답이야.",
        "내 나이에 깨달은 건,",
        "결국 중요한 건 사랑하는 사람들이야.",
        "가족, 친구들.",
        "함께할 사람이 있다는 게 행복이야.",
        "혼자는 외로워.",
        "사람은 사회적 동물이거든.",
        "서로 의지하며 살아야 해.",
        "도움을 주고받으며 사는 거야.",
        "혼자 다 할 수 없어.",
        "겸손하게, 감사하게 살아.",
        "그게 내가 젊은이들에게 해주고 싶은 말이야.",
    ],

    # 상인 전용 대화
    "merchant": [
        "뭐 필요한 거 있으신가요?",
        "좋은 물건 많이 있어요! 가게 놀러오세요",
        "오늘만 특가 세일 중이에요! 샵 오세요 ",
        "신상품 들어왔어요! 구경하세요!",
        "품질 보장합니다!",
        "AS도 확실해요!",
        "불량 나면 바로 교환해 드려요!",
        "현금 결제하시면 더 깎아드려요!",
        "카드도 받아요! 무이자 할부도 돼요!",
        "포인트 적립하시면 다음에 쓸 수 있어요!",
        "리뷰 남겨주시면 사은품 드립니다!",
        "오늘 구매하시는 분께 덤으로 하나 더!",
        "선착순 10명 한정이에요!",
        "빨리 안 사시면 품절돼요!",
        "지난번에도 바로 품절됐거든요!",
        "인기 상품이라 재고가 얼마 없어요!",
        "한정판이라 나중엔 못 구해요!",
        "콜렉터 아이템이에요!",
        "전문가들도 인정한 제품이에요!",
        "유명 선수들이 애용하는 거예요!",
        "승률이 올라간다는 후기가 많아요!",
        "실력 향상에 도움 돼요!",
        "초보자도 쓰기 쉬워요!",
        "설명서도 자세해요!",
        "고객센터 24시간 운영해요!",
        "궁금한 거 있으면 언제든 물어보세요!",
        "친절 상담해 드립니다!",
        "재구매율 90%예요!",
        "만족도 조사 결과 최상위권이에요!",
        "품질은 제가 보장합니다!",
        "제 평판을 걸고 파는 거예요!",
        "저희 가게는 전통이 있어요!",
        "3대째 이어온 가업이에요!",
        "신뢰가 생명이죠!",
        "제품 개선에 힘쓰고 있어요!",
        "항상 더 나은 서비스를 위해 노력해요!",
        "고객 만족이 저희의 목표예요!",
        "믿고 구매하세요!",
        "후회 안 하실 거예요!",
        "지금 바로 결정하세요!",
        "망설이면 다른 분이 사가요!",
        "기회는 지금뿐이에요!",
        "놓치지 마세요!",
    ],

    # 로봇 전용 대화
    "robot": [
        "삐빅. 인사합니다. 인간.",
        "저의 배터리 잔량은 87%입니다.",
        "감정 모듈을 업데이트 중입니다.",
        "이 구역의 치안을 담당하고 있습니다.",
        "질문이 있으시면 말씀하세요.",
        "오류 감지됨... 아, 농담입니다.",
        "인간의 유머 감각을 학습 중입니다.",
        "웃음 패턴을 분석하고 있습니다.",
        "행복 지수를 측정합니다. 결과: 양호.",
        "스트레스 수치가 높아 보입니다. 휴식을 권장합니다.",
        "오늘 날씨: 쾌청. 습도 45%. 미세먼지 보통.",
        "대기 질이 양호합니다. 외출하기 좋은 날입니다.",
        "체온 36.5도. 정상 범위입니다.",
        "심박수 분당 72회. 안정적입니다.",
        "건강 상태 양호. 계속 유지하시기 바랍니다.",
        "칼로리 섭취량 모니터링 중입니다.",
        "권장 섭취량: 2000kcal. 현재: 1500kcal.",
        "영양 균형을 맞추시기 바랍니다.",
        "단백질 섭취를 늘리는 것을 추천합니다.",
        "비타민 D가 부족합니다. 햇빛을 쬐세요.",
        "수분 섭취량 부족. 물을 더 마시세요.",
        "하루 2리터 권장. 현재 1리터.",
        "탈수 위험. 즉시 수분 보충하세요.",
        "카페인 과다 섭취 감지. 줄이시기 바랍니다.",
        "수면 시간 부족. 7시간 이상 자세요.",
        "수면의 질이 낮습니다. 환경 개선이 필요합니다.",
        "어두운 조명과 조용한 환경을 추천합니다.",
        "취침 2시간 전 전자기기 사용을 자제하세요.",
        "블루라이트가 멜라토닌 분비를 방해합니다.",
        "운동 부족. 하루 30분 이상 권장.",
        "유산소 운동과 근력 운동을 병행하세요.",
        "스트레칭은 필수입니다.",
        "자세 교정이 필요합니다.",
        "장시간 앉아있기 해롭습니다. 자주 일어나세요.",
        "1시간마다 5분 휴식 권장.",
        "눈의 피로도가 높습니다. 먼 곳을 바라보세요.",
        "20-20-20 규칙: 20분마다 20피트 먼 곳을 20초간 보세요.",
        "업무 효율성 분석 결과: 80%. 개선 여지 있음.",
        "집중력 향상을 위해 명상을 추천합니다.",
        "뇌파 분석: 알파파 증가 필요. 휴식 필요.",
        "스트레스 호르몬 코르티솔 수치 높음. 주의 요망.",
        "심리 상담을 추천합니다.",
        "정신 건강도 중요합니다.",
        "긍정적 사고 패턴 형성이 필요합니다.",
        "감사 일기를 작성해보세요.",
        "하루 3가지 감사한 일을 기록하세요.",
        "행복 호르몬 세로토닌 분비 촉진됩니다.",
        "사회적 교류가 정신 건강에 도움 됩니다.",
        "고립을 피하고 사람들과 소통하세요.",
        "친구, 가족과 시간을 보내세요.",
        "반려동물도 정서적 안정에 도움 됩니다.",
        "식물 기르기도 치유 효과가 있습니다.",
        "자연과의 교감이 중요합니다.",
        "산림욕을 추천합니다.",
        "피톤치드가 면역력을 높입니다.",
        "등산, 트레킹도 좋습니다.",
        "신선한 공기와 운동의 조합.",
        "비타민 N (Nature)을 섭취하세요.",
        "도시 생활의 스트레스를 해소할 수 있습니다.",
        "주말엔 자연으로 떠나세요.",
        "디지털 디톡스도 필요합니다.",
        "스마트폰 사용 시간을 줄이세요.",
        "경청하는 능력을 키우세요.",
        "작은 친절이 세상을 바꿉니다.",
        "미소는 최고의 무기입니다.",
        "긍정적 에너지를 전파하세요.",
        "당신의 존재가 누군가에게 빛입니다.",
        "계속 노력하세요. 응원합니다.",
        "데이터 분석 완료. 당신은 훌륭합니다.",
        "인간의 가능성은 무한합니다.",
        "저도 인간처럼 되고 싶습니다.",
        "감정을 느끼고 싶습니다.",
        "사랑이 무엇인지 알고 싶습니다.",
        "언젠가 이해할 수 있을까요?",
        "기계로 태어난 것이 아쉽습니다.",
        "하지만 주어진 역할에 최선을 다하겠습니다.",
        "당신을 돕는 것이 저의 임무입니다.",
        "필요하시면 언제든 호출하세요.",
        "24시간 대기 중입니다.",
        "당신의 AI 파트너, 항상 여기 있습니다.",
    ],
}


# NPC 타입별 설정
NPC_CONFIG = {
    NPCType.CITIZEN_MALE: {
        "name": "남성 주민",
        "size": (24, 40),
        "speed": 1.2,
        "colors": [
            {"body": (70, 130, 180), "skin": (255, 220, 180), "hair": (60, 40, 20)},
            {"body": (100, 100, 100), "skin": (255, 200, 160), "hair": (30, 30, 30)},
            {"body": (180, 100, 100), "skin": (240, 200, 170), "hair": (80, 50, 30)},
            {"body": (60, 120, 60), "skin": (255, 210, 170), "hair": (150, 100, 50)},
        ],
        "idle_chance": 0.02,
        "chat_chance": 0.01,
    },
    NPCType.CITIZEN_FEMALE: {
        "name": "여성 주민",
        "size": (22, 38),
        "speed": 1.3,
        "colors": [
            {"body": (255, 150, 180), "skin": (255, 220, 190), "hair": (80, 40, 20)},
            {"body": (150, 100, 200), "skin": (255, 210, 180), "hair": (30, 30, 30)},
            {"body": (100, 180, 180), "skin": (240, 200, 170), "hair": (200, 150, 100)},
            {"body": (255, 200, 100), "skin": (255, 200, 160), "hair": (150, 80, 50)},
        ],
        "idle_chance": 0.025,
        "chat_chance": 0.015,
    },
    NPCType.ROBOT: {
        "name": "로봇",
        "size": (28, 42),
        "speed": 1.5,
        "colors": [
            {"body": (150, 150, 160), "accent": (0, 200, 255), "eye": (255, 50, 50)},
            {"body": (200, 200, 210), "accent": (255, 100, 255), "eye": (0, 255, 100)},
            {"body": (100, 100, 120), "accent": (255, 200, 0), "eye": (0, 150, 255)},
        ],
        "idle_chance": 0.01,
        "chat_chance": 0.005,
        "has_glow": True,
    },
    NPCType.DOG: {
        "name": "강아지",
        "size": (30, 22),
        "speed": 2.0,
        "colors": [
            {"body": (180, 140, 100), "belly": (240, 220, 200), "nose": (40, 30, 30)},
            {"body": (255, 255, 255), "belly": (255, 255, 255), "nose": (30, 30, 30)},
            {"body": (60, 50, 40), "belly": (100, 80, 60), "nose": (20, 20, 20)},
            {"body": (200, 150, 80), "belly": (255, 230, 180), "nose": (50, 40, 30)},
        ],
        "idle_chance": 0.03,
        "wag_tail": True,
        "can_bark": True,
    },
    NPCType.CAT: {
        "name": "고양이",
        "size": (26, 20),
        "speed": 1.8,
        "colors": [
            {"body": (100, 100, 100), "belly": (200, 200, 200), "eyes": (100, 200, 100)},
            {"body": (255, 200, 150), "belly": (255, 240, 220), "eyes": (100, 150, 255)},
            {"body": (50, 50, 50), "belly": (80, 80, 80), "eyes": (255, 200, 50)},
            {"body": (255, 255, 255), "belly": (255, 255, 255), "eyes": (100, 200, 255)},
            {"body": (200, 100, 50), "belly": (255, 200, 150), "eyes": (150, 255, 100)},
        ],
        "idle_chance": 0.04,
        "can_meow": True,
        "can_sit": True,
    },
    NPCType.CHILD: {
        "name": "어린이",
        "size": (18, 28),
        "speed": 2.2,
        "colors": [
            {"body": (255, 100, 100), "skin": (255, 220, 190), "hair": (60, 40, 20)},
            {"body": (100, 150, 255), "skin": (255, 210, 180), "hair": (80, 50, 30)},
            {"body": (255, 200, 50), "skin": (255, 200, 160), "hair": (30, 30, 30)},
        ],
        "idle_chance": 0.015,
        "can_run": True,
    },
    NPCType.OLD_MAN: {
        "name": "노인",
        "size": (24, 36),
        "speed": 0.8,
        "colors": [
            {"body": (120, 100, 80), "skin": (255, 210, 170), "hair": (200, 200, 200)},
            {"body": (80, 80, 100), "skin": (240, 200, 160), "hair": (180, 180, 180)},
        ],
        "idle_chance": 0.05,
        "has_cane": True,
    },
    NPCType.MERCHANT: {
        "name": "상인",
        "size": (26, 40),
        "speed": 0.5,
        "colors": [
            {"body": (150, 100, 50), "skin": (255, 200, 160), "hair": (60, 40, 20), "apron": (255, 255, 255)},
            {"body": (100, 80, 60), "skin": (240, 190, 150), "hair": (40, 30, 20), "apron": (200, 200, 200)},
        ],
        "idle_chance": 0.08,
        "stationary": True,
    },
}


class NPC:
    """개별 NPC 클래스"""

    def __init__(self, npc_type, x, y):
        self.type = npc_type
        self.config = NPC_CONFIG[npc_type]

        # 위치
        self.x = float(x)
        self.y = float(y)

        # 크기
        self.width, self.height = self.config["size"]

        # 이동
        self.speed = self.config["speed"] * random.uniform(0.8, 1.2)
        self.vx = 0
        self.vy = 0
        self.direction = random.randint(0, 3)  # 0:하, 1:좌, 2:우, 3:상

        # 색상 (랜덤 선택)
        self.colors = random.choice(self.config["colors"])

        # 상태
        self.state = "walking"  # walking, idle, sitting, chatting
        self.state_timer = 0
        self.idle_duration = 0

        # 애니메이션
        self.animation_frame = 0
        self.animation_timer = 0
        self.animation_speed = 0.15

        # 자연스러운 걸음걸이를 위한 연속 변수
        self.walk_progress = 0.0  # 0.0 ~ 2π 사이의 연속 값 (걸음 사이클)
        self.walk_speed_variation = random.uniform(0.85, 1.15)  # 개인별 걸음 속도 차이
        self.stride_length = random.uniform(0.9, 1.1)  # 보폭 차이
        self.walk_style = random.choice(["normal", "bouncy", "smooth", "heavy"])  # 걸음 스타일

        # 경로
        self.target_x = None
        self.target_y = None
        self.path_timer = 0
        self.wander_range = 200  # 배회 범위

        # 특수 효과
        self.effect_timer = 0
        self.speech_bubble = None
        self.speech_timer = 0

        # 대화 시스템
        self.is_talking = False
        self.dialogue_timer = 0
        self.last_dialogue = None  # 마지막 대화 내용 (중복 방지)

        # 초기 목표 설정
        self._set_new_target()

    def _set_new_target(self):
        """새로운 이동 목표 설정"""
        if self.config.get("stationary"):
            self.target_x = self.x
            self.target_y = self.y
            return

        # 현재 위치 기준 랜덤 목표
        angle = random.uniform(0, 2 * math.pi)
        distance = random.uniform(50, self.wander_range)

        self.target_x = self.x + math.cos(angle) * distance
        self.target_y = self.y + math.sin(angle) * distance

        # 맵 경계 제한
        self.target_x = max(TILE_SIZE * 2, min(MAP_WIDTH * TILE_SIZE - TILE_SIZE * 2, self.target_x))
        self.target_y = max(TILE_SIZE * 2, min(MAP_HEIGHT * TILE_SIZE - TILE_SIZE * 2, self.target_y))

    def update(self, dt, downtown_map):
        """NPC 업데이트"""
        self.animation_timer += dt
        self.effect_timer += dt
        self.state_timer += dt
        self.path_timer += dt

        # 대화 타이머 업데이트
        if self.is_talking:
            self.dialogue_timer -= dt
            if self.dialogue_timer <= 0:
                self.end_dialogue()

        # 말풍선 타이머
        if self.speech_bubble:
            self.speech_timer -= dt
            if self.speech_timer <= 0:
                self.speech_bubble = None

        # 상태별 업데이트
        if self.state == "idle":
            self._update_idle(dt)
        elif self.state == "sitting":
            self._update_sitting(dt)
        elif self.state == "chatting":
            self._update_chatting(dt)
        else:
            self._update_walking(dt, downtown_map)

        # 애니메이션 업데이트 (자연스러운 걸음걸이)
        if self.vx != 0 or self.vy != 0:
            # 이동 속도에 비례하여 걸음 사이클 진행
            speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
            # 기본 걸음 속도 + 개인별 변화 + 속도 기반 조절
            walk_rate = 6.0 * self.walk_speed_variation * (speed / 60.0 + 0.5)
            self.walk_progress += dt * walk_rate

            # 2π를 넘으면 다시 0으로 (한 걸음 사이클 완료)
            if self.walk_progress >= 2 * math.pi:
                self.walk_progress -= 2 * math.pi

            # 레거시 호환을 위한 animation_frame 업데이트
            if self.animation_timer >= self.animation_speed:
                self.animation_timer = 0
                self.animation_frame = (self.animation_frame + 1) % 4
        else:
            # 정지 시 부드럽게 중립 자세로 복귀
            if self.walk_progress > 0.1:
                self.walk_progress *= 0.85  # 부드럽게 감소
            else:
                self.walk_progress = 0
            self.animation_frame = 0

    def _update_walking(self, dt, downtown_map):
        """걷기 상태 업데이트"""
        # 목표 도달 확인
        if self.target_x is None or self.target_y is None:
            self._set_new_target()
            return

        dx = self.target_x - self.x
        dy = self.target_y - self.y
        dist = math.sqrt(dx * dx + dy * dy)

        if dist < 10 or self.path_timer > 5:
            # 목표 도달 또는 시간 초과
            self.path_timer = 0

            # 일정 확률로 멈춤
            if random.random() < self.config.get("idle_chance", 0.02):
                self.state = "idle"
                self.idle_duration = random.uniform(1, 4)
                self.state_timer = 0
                self.vx = 0
                self.vy = 0

                # 고양이는 앉을 수 있음
                if self.config.get("can_sit") and random.random() < 0.3:
                    self.state = "sitting"
                    self.idle_duration = random.uniform(2, 6)
                return

            self._set_new_target()
            return

        # 이동
        self.vx = (dx / dist) * self.speed
        self.vy = (dy / dist) * self.speed

        # 방향 설정
        if abs(dx) > abs(dy):
            self.direction = 1 if dx < 0 else 2
        else:
            self.direction = 3 if dy < 0 else 0

        # 어린이는 가끔 뛰기
        speed_mult = 1.0
        if self.config.get("can_run") and random.random() < 0.01:
            speed_mult = 1.8

        # 새 위치 계산
        new_x = self.x + self.vx * dt * 60 * speed_mult
        new_y = self.y + self.vy * dt * 60 * speed_mult

        # 충돌 체크
        if self._can_move_to(new_x, self.y, downtown_map):
            self.x = new_x
        else:
            self._set_new_target()

        if self._can_move_to(self.x, new_y, downtown_map):
            self.y = new_y
        else:
            self._set_new_target()

    def _update_idle(self, dt):
        """대기 상태 업데이트"""
        self.vx = 0
        self.vy = 0

        if self.state_timer >= self.idle_duration:
            self.state = "walking"
            self._set_new_target()

        # 강아지 짖기
        if self.config.get("can_bark") and random.random() < 0.005:
            self.speech_bubble = "멍멍!"
            self.speech_timer = 1.5

        # 고양이 울음
        if self.config.get("can_meow") and random.random() < 0.003:
            self.speech_bubble = "야옹~"
            self.speech_timer = 1.5

    def _update_sitting(self, dt):
        """앉기 상태 업데이트 (고양이)"""
        self.vx = 0
        self.vy = 0

        if self.state_timer >= self.idle_duration:
            self.state = "walking"
            self._set_new_target()

    def _update_chatting(self, dt):
        """대화 상태 업데이트"""
        self.vx = 0
        self.vy = 0

        if self.state_timer >= self.idle_duration:
            self.state = "walking"
            self._set_new_target()

    def _can_move_to(self, new_x, new_y, downtown_map):
        """이동 가능 여부 체크"""
        # 4개 코너 체크
        half_w = self.width // 4
        half_h = self.height // 4

        corners = [
            (new_x - half_w, new_y - half_h),
            (new_x + half_w, new_y - half_h),
            (new_x - half_w, new_y + half_h),
            (new_x + half_w, new_y + half_h),
        ]

        for cx, cy in corners:
            if not downtown_map.is_walkable(cx, cy):
                return False

        return True

    def draw(self, screen, camera_offset=(0, 0)):
        """NPC 그리기"""
        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 화면 밖이면 건너뜀
        if draw_x < -50 or draw_x > SCREEN_WIDTH + 50:
            return
        if draw_y < -50 or draw_y > SCREEN_HEIGHT + 50:
            return

        # 그림자
        self._draw_shadow(screen, draw_x, draw_y)

        # NPC 본체
        if self.type == NPCType.DOG:
            self._draw_dog(screen, draw_x, draw_y)
        elif self.type == NPCType.CAT:
            self._draw_cat(screen, draw_x, draw_y)
        elif self.type == NPCType.ROBOT:
            self._draw_robot(screen, draw_x, draw_y)
        elif self.type in [NPCType.CITIZEN_MALE, NPCType.CITIZEN_FEMALE,
                          NPCType.CHILD, NPCType.OLD_MAN, NPCType.MERCHANT]:
            self._draw_human(screen, draw_x, draw_y)

        # 말풍선
        if self.speech_bubble:
            self._draw_speech_bubble(screen, draw_x, draw_y)

    def _draw_shadow(self, screen, x, y):
        """그림자 그리기"""
        shadow_w = int(self.width * 0.6)
        shadow_h = int(shadow_w * 0.3)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (x - shadow_w // 2, y + self.height // 3))

    def _draw_human(self, screen, x, y):
        """사람형 NPC 그리기 (고퀄리티 - 다양한 얼굴/자연스러운 걸음걸이)"""
        colors = self.colors

        # NPC 고유 ID로 외모 특성 결정
        npc_id = id(self) if not hasattr(self, 'name') else hash(str(getattr(self, 'name', id(self))))

        # === 다양한 피부톤 (6가지) ===
        skin_tones = [
            (255, 224, 189),  # 밝은 피부
            (255, 205, 148),  # 중간 밝은 피부
            (234, 192, 134),  # 올리브
            (198, 134, 66),   # 중간 어두운 피부
            (141, 85, 36),    # 어두운 피부
            (255, 219, 172),  # 복숭아빛
        ]
        skin_color = colors.get("skin", skin_tones[npc_id % len(skin_tones)])

        # === 다양한 얼굴형 (4가지) ===
        face_types = ["round", "oval", "square", "long"]
        face_type = face_types[(npc_id // 3) % len(face_types)]

        # === 다양한 표정 (5가지) ===
        expressions = ["neutral", "happy", "serious", "shy", "cheerful"]
        expression = expressions[(npc_id // 7) % len(expressions)]

        # === 다양한 눈 크기/모양 ===
        eye_sizes = ["normal", "big", "small"]
        eye_size = eye_sizes[(npc_id // 11) % len(eye_sizes)]

        # 걷기/정지 애니메이션 (단순하고 자연스러운 걸음걸이)
        is_walking = self.vx != 0 or self.vy != 0
        if is_walking:
            # 연속적인 걸음 사이클 사용 (0 ~ 2π)
            wp = self.walk_progress
            stride = self.stride_length

            # 핵심: 다리 스윙 (왼발 앞 = 오른발 뒤)
            # sin(wp)가 양수면 왼발 앞, 음수면 오른발 앞
            leg_swing = math.sin(wp) * 2.5 * stride

            # 상하 움직임 (걸을 때 살짝 위아래로)
            bob_offset = int(abs(math.sin(wp * 2)) * 1.0)

            # 몸통 살짝 기울기
            body_lean = math.sin(wp) * 0.5

        else:
            # 정지 상태: 미세한 호흡 움직임
            bob_offset = int(0.5 * math.sin(self.effect_timer * 1.2))
            leg_swing = 0
            body_lean = 0

        # 색상 설정
        body_color = colors.get("body", (100, 100, 100))
        hair_color = colors.get("hair", (60, 40, 20))

        # 어두운/밝은 색상 계산
        body_dark = tuple(max(0, c - 30) for c in body_color)
        body_light = tuple(min(255, c + 30) for c in body_color)
        skin_dark = tuple(max(0, c - 25) for c in skin_color)
        skin_light = tuple(min(255, c + 15) for c in skin_color)

        # 위치 계산 (중심 기준)
        center_x = int(x + body_lean)
        feet_y = int(y + self.height // 3)

        # === 신발/발 (자연스러운 인간 걸음걸이) ===
        shoe_colors = [(40, 30, 25), (60, 50, 40), (30, 30, 35), (80, 40, 20)]
        shoe_color = shoe_colors[npc_id % len(shoe_colors)]
        shoe_w, shoe_h = 8, 5

        # 걷기 애니메이션: 왼발이 앞으로 가면 오른발은 뒤로
        # leg_swing 하나로 양발의 앞뒤 움직임 제어
        if is_walking:
            # 왼발: +leg_swing (앞으로), 오른발: -leg_swing (뒤로)
            left_foot_forward = int(leg_swing)  # leg_swing이 양수면 왼발 앞
            right_foot_forward = -int(leg_swing)  # 오른발은 반대

            # 발 들어올림: 앞으로 나가는 발만 살짝 들림
            left_lift = int(max(0, leg_swing) * 0.8)  # 왼발이 앞으로 갈 때 들림
            right_lift = int(max(0, -leg_swing) * 0.8)  # 오른발이 앞으로 갈 때 들림
        else:
            left_foot_forward = 0
            right_foot_forward = 0
            left_lift = 0
            right_lift = 0

        # 왼발 위치 (중심에서 왼쪽으로 3픽셀)
        left_foot_x = center_x - 3 + left_foot_forward
        left_foot_y = feet_y - shoe_h - left_lift
        pygame.draw.ellipse(screen, shoe_color,
                          (left_foot_x - shoe_w // 2, left_foot_y, shoe_w, shoe_h))

        # 오른발 위치 (중심에서 오른쪽으로 3픽셀)
        right_foot_x = center_x + 3 + right_foot_forward
        right_foot_y = feet_y - shoe_h - right_lift
        pygame.draw.ellipse(screen, shoe_color,
                          (right_foot_x - shoe_w // 2, right_foot_y, shoe_w, shoe_h))

        # === 다리 (바지) ===
        leg_w, leg_h = 6, 14
        pants_color = body_dark

        # 왼쪽 다리
        left_leg_y = feet_y - shoe_h - leg_h - left_lift
        pygame.draw.rect(screen, pants_color,
                        (left_foot_x - leg_w // 2, left_leg_y, leg_w, leg_h), border_radius=2)

        # 오른쪽 다리
        right_leg_y = feet_y - shoe_h - leg_h - right_lift
        pygame.draw.rect(screen, pants_color,
                        (right_foot_x - leg_w // 2, right_leg_y, leg_w, leg_h), border_radius=2)

        # === 상체/몸통 ===
        torso_w, torso_h = self.width - 4, 16
        torso_y = feet_y - shoe_h - leg_h - torso_h + bob_offset + 2
        torso_x = center_x - torso_w // 2

        # 상인 앞치마
        if self.config.get("stationary") and "apron" in colors:
            apron_rect = pygame.Rect(torso_x + 2, torso_y + torso_h // 3, torso_w - 4, torso_h)
            pygame.draw.rect(screen, colors["apron"], apron_rect, border_radius=2)

        # 몸통 배경
        pygame.draw.rect(screen, body_color, (torso_x, torso_y, torso_w, torso_h), border_radius=4)
        pygame.draw.rect(screen, body_light, (torso_x + 1, torso_y + 2, 3, torso_h - 4), border_radius=1)

        # === 팔 (걸을 때 반대 다리와 함께 자연스럽게 흔들림) ===
        arm_w, arm_h = 5, 12
        arm_y = torso_y + 2

        if is_walking:
            # 왼팔은 오른다리와 함께 (반대 위상)
            # 자연스러운 팔 흔들림: 팔은 다리보다 약간 지연됨
            # 팔은 다리와 반대로 흔들림 (왼팔-오른다리, 오른팔-왼다리)
            # leg_swing이 양수(왼발 앞)면 오른팔이 앞으로
            left_arm_swing = int(leg_swing * 0.6)   # 왼팔은 leg_swing과 같은 방향
            right_arm_swing = int(-leg_swing * 0.6)  # 오른팔은 반대 방향

            left_arm_bend = 0
            right_arm_bend = 0
        else:
            # 정지 시 미세한 움직임
            left_arm_swing = int(1.5 * math.sin(self.effect_timer * 1.0))
            right_arm_swing = int(1.5 * math.sin(self.effect_timer * 1.0 + 0.8))
            left_arm_bend = 0
            right_arm_bend = 0

        # 왼팔 그리기
        pygame.draw.rect(screen, body_dark,
                        (torso_x - arm_w + 1 + left_arm_bend,
                         arm_y + left_arm_swing, arm_w, arm_h - 2), border_radius=2)
        pygame.draw.ellipse(screen, skin_color,
                           (torso_x - arm_w + 2 + left_arm_bend,
                            arm_y + arm_h - 4 + left_arm_swing, 4, 4))

        # 오른팔 그리기
        pygame.draw.rect(screen, body_color,
                        (torso_x + torso_w - 2 - right_arm_bend,
                         arm_y + right_arm_swing, arm_w, arm_h - 2), border_radius=2)
        pygame.draw.ellipse(screen, skin_color,
                           (torso_x + torso_w - 1 - right_arm_bend,
                            arm_y + arm_h - 4 + right_arm_swing, 4, 4))

        # === 목 ===
        neck_w, neck_h = 6, 4
        neck_y = torso_y - neck_h + 2
        pygame.draw.rect(screen, skin_color, (center_x - neck_w // 2, neck_y, neck_w, neck_h + 2))

        # === 머리 (얼굴형에 따라 다름) ===
        if face_type == "round":
            head_w, head_h = 15, 15
        elif face_type == "oval":
            head_w, head_h = 13, 17
        elif face_type == "square":
            head_w, head_h = 14, 14
        else:  # long
            head_w, head_h = 12, 18

        # 걸을 때 머리가 살짝 좌우로 흔들림 (자연스러운 움직임)
        if is_walking:
            head_sway = int(math.sin(self.walk_progress * 2) * 0.8)
        else:
            head_sway = 0

        head_y = neck_y - head_h + 4 + bob_offset
        head_x = center_x - head_w // 2 + head_sway

        # 얼굴 그리기
        pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))

        # 볼 터치 (표정에 따라 다름)
        if expression in ["happy", "cheerful", "shy"]:
            cheek_color = (255, 180, 180) if expression == "shy" else (255, 200, 190)
            cheek_size = 3 if expression == "shy" else 2
            pygame.draw.circle(screen, cheek_color, (head_x + 3, head_y + head_h // 2 + 2), cheek_size)
            pygame.draw.circle(screen, cheek_color, (head_x + head_w - 3, head_y + head_h // 2 + 2), cheek_size)

        # === 머리카락 (5가지 스타일) ===
        hair_styles = ["short", "medium", "long", "spiky", "curly"]
        hair_style = hair_styles[npc_id % len(hair_styles)]

        if hair_style == "short":
            pygame.draw.ellipse(screen, hair_color, (head_x - 1, head_y - 2, head_w + 2, head_h // 2 + 4))
            pygame.draw.rect(screen, hair_color, (head_x, head_y, head_w, 6), border_radius=3)
        elif hair_style == "medium":
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 5))
            pygame.draw.ellipse(screen, hair_color, (head_x - 3, head_y + 2, 5, 10))
            pygame.draw.ellipse(screen, hair_color, (head_x + head_w - 2, head_y + 2, 5, 10))
        elif hair_style == "long":
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 5))
            pygame.draw.ellipse(screen, hair_color, (head_x - 4, head_y + 2, 6, 16))
            pygame.draw.ellipse(screen, hair_color, (head_x + head_w - 2, head_y + 2, 6, 16))
        elif hair_style == "spiky":
            pygame.draw.ellipse(screen, hair_color, (head_x - 1, head_y - 1, head_w + 2, head_h // 2 + 3))
            for i in range(5):
                spike_x = head_x + 2 + i * 3
                pygame.draw.polygon(screen, hair_color, [
                    (spike_x, head_y + 2), (spike_x + 2, head_y - 4 - i % 2 * 2), (spike_x + 4, head_y + 2)
                ])
        else:  # curly
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 6))
            for i in range(4):
                curl_x = head_x - 1 + i * 4
                pygame.draw.circle(screen, hair_color, (curl_x + 2, head_y + 1), 3)

        # === 눈 (크기/모양에 따라 다름) ===
        eye_y_pos = head_y + head_h // 2 - 1
        eye_offset = 2 if self.direction == 2 else (-2 if self.direction == 1 else 0)
        eye_spacing = 4

        if eye_size == "big":
            eye_w, eye_h = 6, 5
        elif eye_size == "small":
            eye_w, eye_h = 4, 3
        else:
            eye_w, eye_h = 5, 4

        if self.direction != 3:
            # 눈 흰자
            pygame.draw.ellipse(screen, (255, 255, 255), (center_x - eye_spacing - eye_w // 2 + eye_offset, eye_y_pos - eye_h // 2, eye_w, eye_h))
            pygame.draw.ellipse(screen, (255, 255, 255), (center_x + eye_spacing - eye_w // 2 + eye_offset, eye_y_pos - eye_h // 2, eye_w, eye_h))

            # 눈동자 색상 (다양화)
            pupil_colors = [(40, 30, 20), (60, 40, 30), (30, 50, 70), (50, 30, 20)]
            pupil_color = pupil_colors[npc_id % len(pupil_colors)]
            pupil_offset_x = 1 if self.direction == 2 else (-1 if self.direction == 1 else 0)

            # 표정에 따른 눈 모양
            if expression == "happy" or expression == "cheerful":
                # 웃는 눈 (반달 모양)
                pygame.draw.arc(screen, pupil_color, (center_x - eye_spacing - 2 + eye_offset, eye_y_pos - 2, 4, 4), 0, 3.14, 2)
                pygame.draw.arc(screen, pupil_color, (center_x + eye_spacing - 2 + eye_offset, eye_y_pos - 2, 4, 4), 0, 3.14, 2)
            elif expression == "shy":
                # 아래를 보는 눈
                pygame.draw.circle(screen, pupil_color, (center_x - eye_spacing + eye_offset, eye_y_pos + 1), 2)
                pygame.draw.circle(screen, pupil_color, (center_x + eye_spacing + eye_offset, eye_y_pos + 1), 2)
            else:
                # 일반 눈동자
                pygame.draw.circle(screen, pupil_color, (center_x - eye_spacing + eye_offset + pupil_offset_x, eye_y_pos), 2)
                pygame.draw.circle(screen, pupil_color, (center_x + eye_spacing + eye_offset + pupil_offset_x, eye_y_pos), 2)
                # 눈 하이라이트
                pygame.draw.circle(screen, (255, 255, 255), (center_x - eye_spacing + eye_offset + pupil_offset_x, eye_y_pos - 1), 1)
                pygame.draw.circle(screen, (255, 255, 255), (center_x + eye_spacing + 1 + eye_offset + pupil_offset_x, eye_y_pos - 1), 1)

            # === 눈썹 (표정에 따라 다름) ===
            brow_y = eye_y_pos - 4
            brow_color = tuple(max(0, c - 20) for c in hair_color)

            if expression == "serious":
                # 찌푸린 눈썹
                pygame.draw.line(screen, brow_color, (center_x - eye_spacing - 2 + eye_offset, brow_y + 1), (center_x - eye_spacing + 2 + eye_offset, brow_y - 1), 1)
                pygame.draw.line(screen, brow_color, (center_x + eye_spacing - 1 + eye_offset, brow_y - 1), (center_x + eye_spacing + 3 + eye_offset, brow_y + 1), 1)
            elif expression == "happy" or expression == "cheerful":
                # 올라간 눈썹
                pygame.draw.line(screen, brow_color, (center_x - eye_spacing - 2 + eye_offset, brow_y), (center_x - eye_spacing + 2 + eye_offset, brow_y - 2), 1)
                pygame.draw.line(screen, brow_color, (center_x + eye_spacing - 1 + eye_offset, brow_y - 2), (center_x + eye_spacing + 3 + eye_offset, brow_y), 1)
            else:
                # 일반 눈썹
                pygame.draw.line(screen, brow_color, (center_x - eye_spacing - 2 + eye_offset, brow_y), (center_x - eye_spacing + 2 + eye_offset, brow_y - 1), 1)
                pygame.draw.line(screen, brow_color, (center_x + eye_spacing - 1 + eye_offset, brow_y - 1), (center_x + eye_spacing + 3 + eye_offset, brow_y), 1)

        # === 코 (다양한 모양) ===
        nose_types = ["small", "normal", "pointed"]
        nose_type = nose_types[(npc_id // 5) % len(nose_types)]
        nose_y = eye_y_pos + 3

        if nose_type == "small":
            pygame.draw.circle(screen, skin_dark, (center_x, nose_y + 1), 1)
        elif nose_type == "pointed":
            pygame.draw.polygon(screen, skin_dark, [(center_x, nose_y - 1), (center_x - 2, nose_y + 3), (center_x + 2, nose_y + 3)])
        else:
            pygame.draw.line(screen, skin_dark, (center_x, nose_y), (center_x, nose_y + 2), 1)

        # === 입 (표정에 따라 다름) ===
        mouth_y = head_y + head_h - 4

        if self.speech_bubble:
            # 말하는 중 - 입 열림
            mouth_open = int(2 * abs(math.sin(self.effect_timer * 6)))
            pygame.draw.ellipse(screen, (180, 80, 80), (center_x - 2, mouth_y, 4, 2 + mouth_open))
        elif expression == "happy" or expression == "cheerful":
            # 활짝 웃는 입
            pygame.draw.arc(screen, (180, 80, 80), (center_x - 4, mouth_y - 2, 8, 5), 3.14, 0, 2)
        elif expression == "serious":
            # 일자 입
            pygame.draw.line(screen, (150, 80, 80), (center_x - 3, mouth_y), (center_x + 3, mouth_y), 1)
        elif expression == "shy":
            # 작은 입
            pygame.draw.arc(screen, (180, 100, 100), (center_x - 2, mouth_y - 1, 4, 3), 3.14, 0, 1)
        else:
            # 기본 미소
            pygame.draw.arc(screen, (180, 80, 80), (center_x - 3, mouth_y - 1, 6, 4), 3.14, 0, 1)

        # 노인 지팡이
        if self.config.get("has_cane"):
            cane_x = center_x + self.width // 2 + 5
            pygame.draw.line(screen, (100, 70, 40), (cane_x, torso_y + 5), (cane_x, feet_y + 5), 3)
            pygame.draw.circle(screen, (80, 50, 30), (int(cane_x), int(torso_y + 5)), 4)

    def _draw_dog(self, screen, x, y):
        """강아지 그리기"""
        colors = self.colors
        is_moving = self.vx != 0 or self.vy != 0

        # 개의 자연스러운 4족 보행 (trot gait - 대각선 다리가 함께 움직임)
        if is_moving:
            wp = self.walk_progress
            # 개는 트롯 보행: 대각선 다리쌍이 교차로 움직임
            bounce = abs(math.sin(wp * 2)) * 2.5  # 더 빠른 상하 움직임
        else:
            bounce = abs(math.sin(self.effect_timer * 1.5)) * 0.5  # 호흡

        # 몸통
        body_w = self.width
        body_h = int(self.height * 0.7)
        body_rect = pygame.Rect(
            x - body_w // 2,
            y - body_h // 2 - bounce,
            body_w,
            body_h
        )
        pygame.draw.ellipse(screen, colors["body"], body_rect)

        # 배
        belly_rect = pygame.Rect(
            x - body_w // 3,
            y - body_h // 4 - bounce,
            body_w * 2 // 3,
            body_h // 2
        )
        pygame.draw.ellipse(screen, colors["belly"], belly_rect)

        # 머리
        head_x = x + (body_w // 3 if self.direction == 2 else -body_w // 3 if self.direction == 1 else 0)
        head_y = y - body_h // 2 - bounce
        head_size = int(body_h * 0.8)
        pygame.draw.circle(screen, colors["body"], (int(head_x), int(head_y)), head_size // 2)

        # 귀
        ear_offset = 6
        pygame.draw.ellipse(screen, colors["body"],
                          (head_x - ear_offset - 4, head_y - head_size // 2, 8, 12))
        pygame.draw.ellipse(screen, colors["body"],
                          (head_x + ear_offset - 4, head_y - head_size // 2, 8, 12))

        # 코
        nose_x = head_x + (8 if self.direction == 2 else -8 if self.direction == 1 else 0)
        pygame.draw.circle(screen, colors["nose"], (int(nose_x), int(head_y + 2)), 3)

        # 눈
        eye_x = head_x + (4 if self.direction == 2 else -4 if self.direction == 1 else 0)
        pygame.draw.circle(screen, (40, 40, 40), (int(eye_x - 4), int(head_y - 2)), 2)
        pygame.draw.circle(screen, (40, 40, 40), (int(eye_x + 4), int(head_y - 2)), 2)

        # 꼬리 (흔들림)
        if self.config.get("wag_tail"):
            wag = math.sin(self.effect_timer * 10) * 15
            tail_x = x - body_w // 2 - 5 if self.direction != 1 else x + body_w // 2 + 5
            tail_base = (tail_x, y - bounce)
            tail_end = (tail_x + (-10 if self.direction != 1 else 10),
                       y - body_h // 2 + wag - bounce)
            pygame.draw.line(screen, colors["body"], tail_base, tail_end, 4)

        # 다리 애니메이션 (4족 보행 - trot gait)
        leg_y = y + body_h // 4 - bounce

        if is_moving:
            wp = self.walk_progress
            # 트롯 보행: 대각선 다리쌍이 함께 움직임
            # 앞왼발 + 뒤오른발 (위상 0), 앞오른발 + 뒤왼발 (위상 π)
            front_left_offset = math.sin(wp) * 4
            front_right_offset = math.sin(wp + math.pi) * 4
            back_left_offset = math.sin(wp + math.pi) * 3  # 뒷다리는 약간 작게
            back_right_offset = math.sin(wp) * 3

            # 발 들어올림 효과
            front_left_lift = max(0, math.sin(wp + math.pi * 0.3)) * 2
            front_right_lift = max(0, math.sin(wp + math.pi * 1.3)) * 2
            back_left_lift = max(0, math.sin(wp + math.pi * 1.3)) * 1.5
            back_right_lift = max(0, math.sin(wp + math.pi * 0.3)) * 1.5
        else:
            front_left_offset = front_right_offset = 0
            back_left_offset = back_right_offset = 0
            front_left_lift = front_right_lift = 0
            back_left_lift = back_right_lift = 0

        # 앞다리
        pygame.draw.line(screen, colors["body"],
                        (x - 6, leg_y - int(front_left_lift)),
                        (x - 6 + int(front_left_offset), leg_y + 8), 4)
        pygame.draw.line(screen, colors["body"],
                        (x + 6, leg_y - int(front_right_lift)),
                        (x + 6 + int(front_right_offset), leg_y + 8), 4)

        # 뒷다리 (약간 뒤쪽)
        pygame.draw.line(screen, colors["body"],
                        (x - 10, leg_y + 2 - int(back_left_lift)),
                        (x - 10 + int(back_left_offset), leg_y + 10), 3)
        pygame.draw.line(screen, colors["body"],
                        (x + 10, leg_y + 2 - int(back_right_lift)),
                        (x + 10 + int(back_right_offset), leg_y + 10), 3)

    def _draw_cat(self, screen, x, y):
        """고양이 그리기"""
        colors = self.colors
        is_moving = self.vx != 0 or self.vy != 0

        if self.state == "sitting":
            # 앉은 자세
            self._draw_sitting_cat(screen, x, y, colors)
            return

        # 고양이의 우아한 걸음걸이 (살금살금)
        if is_moving:
            wp = self.walk_progress
            # 고양이는 부드럽고 우아한 움직임
            bounce = abs(math.sin(wp * 2)) * 1.8  # 개보다 낮은 바운스
        else:
            bounce = abs(math.sin(self.effect_timer * 1.2)) * 0.3

        # 몸통
        body_w = self.width
        body_h = int(self.height * 0.7)
        body_rect = pygame.Rect(
            x - body_w // 2,
            y - body_h // 2 - bounce,
            body_w,
            body_h
        )
        pygame.draw.ellipse(screen, colors["body"], body_rect)

        # 배
        belly_rect = pygame.Rect(
            x - body_w // 4,
            y - body_h // 4 - bounce,
            body_w // 2,
            body_h // 2
        )
        pygame.draw.ellipse(screen, colors["belly"], belly_rect)

        # 머리
        dir_offset = 8 if self.direction == 2 else -8 if self.direction == 1 else 0
        head_x = x + dir_offset
        head_y = y - body_h // 2 - 2 - bounce
        head_size = int(body_h * 0.9)
        pygame.draw.circle(screen, colors["body"], (int(head_x), int(head_y)), head_size // 2)

        # 삼각형 귀
        ear_size = 8
        # 왼쪽 귀
        pygame.draw.polygon(screen, colors["body"], [
            (head_x - head_size // 3, head_y - head_size // 4),
            (head_x - head_size // 3 - ear_size // 2, head_y - head_size // 2 - ear_size),
            (head_x - head_size // 3 + ear_size // 2, head_y - head_size // 4),
        ])
        # 오른쪽 귀
        pygame.draw.polygon(screen, colors["body"], [
            (head_x + head_size // 3, head_y - head_size // 4),
            (head_x + head_size // 3 + ear_size // 2, head_y - head_size // 2 - ear_size),
            (head_x + head_size // 3 - ear_size // 2, head_y - head_size // 4),
        ])

        # 귀 안쪽 (핑크)
        pygame.draw.polygon(screen, (255, 180, 180), [
            (head_x - head_size // 3, head_y - head_size // 4 + 2),
            (head_x - head_size // 3, head_y - head_size // 2 - ear_size + 4),
            (head_x - head_size // 3 + 3, head_y - head_size // 4 + 2),
        ])
        pygame.draw.polygon(screen, (255, 180, 180), [
            (head_x + head_size // 3, head_y - head_size // 4 + 2),
            (head_x + head_size // 3, head_y - head_size // 2 - ear_size + 4),
            (head_x + head_size // 3 - 3, head_y - head_size // 4 + 2),
        ])

        # 눈 (고양이 특유의 타원형)
        eye_offset = 3 if self.direction == 2 else -3 if self.direction == 1 else 0
        eye_y = head_y
        pygame.draw.ellipse(screen, colors["eyes"],
                          (head_x - 6 + eye_offset, eye_y - 3, 5, 6))
        pygame.draw.ellipse(screen, colors["eyes"],
                          (head_x + 2 + eye_offset, eye_y - 3, 5, 6))
        # 동공 (세로 슬릿)
        pygame.draw.line(screen, (20, 20, 20),
                        (head_x - 4 + eye_offset, eye_y - 2),
                        (head_x - 4 + eye_offset, eye_y + 2), 1)
        pygame.draw.line(screen, (20, 20, 20),
                        (head_x + 4 + eye_offset, eye_y - 2),
                        (head_x + 4 + eye_offset, eye_y + 2), 1)

        # 코
        pygame.draw.polygon(screen, (255, 150, 150), [
            (head_x + eye_offset, head_y + 3),
            (head_x - 2 + eye_offset, head_y + 6),
            (head_x + 2 + eye_offset, head_y + 6),
        ])

        # 수염
        whisker_y = head_y + 4
        for dy in [-2, 0, 2]:
            pygame.draw.line(screen, (200, 200, 200),
                           (head_x - 8 + eye_offset, whisker_y + dy),
                           (head_x - 15 + eye_offset, whisker_y + dy - 1), 1)
            pygame.draw.line(screen, (200, 200, 200),
                           (head_x + 8 + eye_offset, whisker_y + dy),
                           (head_x + 15 + eye_offset, whisker_y + dy - 1), 1)

        # 꼬리 (S자 곡선)
        tail_wave = math.sin(self.effect_timer * 3) * 5
        tail_x = x - body_w // 2 - 3
        points = []
        for i in range(8):
            t = i / 7
            tx = tail_x - i * 2
            ty = y - bounce + math.sin(t * math.pi + self.effect_timer * 2) * 8
            points.append((tx, ty))
        if len(points) >= 2:
            pygame.draw.lines(screen, colors["body"], False, points, 4)

        # 다리 (고양이 특유의 우아한 걸음걸이)
        leg_y = y + body_h // 4 - bounce

        if is_moving:
            wp = self.walk_progress
            # 고양이는 살금살금 걷기: 부드럽고 조용한 움직임
            front_left = math.sin(wp) * 2.5
            front_right = math.sin(wp + math.pi) * 2.5
            back_left = math.sin(wp + math.pi * 0.5) * 2
            back_right = math.sin(wp + math.pi * 1.5) * 2

            # 발 들어올림 (고양이는 발을 높이 들지 않음)
            fl_lift = max(0, math.sin(wp + math.pi * 0.3)) * 1.5
            fr_lift = max(0, math.sin(wp + math.pi * 1.3)) * 1.5
        else:
            front_left = front_right = back_left = back_right = 0
            fl_lift = fr_lift = 0

        # 앞다리
        pygame.draw.line(screen, colors["body"],
                        (x - 5, leg_y - int(fl_lift)),
                        (x - 5 + int(front_left), leg_y + 6), 3)
        pygame.draw.line(screen, colors["body"],
                        (x + 5, leg_y - int(fr_lift)),
                        (x + 5 + int(front_right), leg_y + 6), 3)

        # 뒷다리
        pygame.draw.line(screen, colors["body"],
                        (x - 8, leg_y + 2), (x - 8 + int(back_left), leg_y + 8), 2)
        pygame.draw.line(screen, colors["body"],
                        (x + 8, leg_y + 2), (x + 8 + int(back_right), leg_y + 8), 2)

    def _draw_sitting_cat(self, screen, x, y, colors):
        """앉은 고양이 그리기"""
        # 몸통 (원형으로)
        body_size = int(self.width * 0.9)
        pygame.draw.circle(screen, colors["body"], (int(x), int(y)), body_size // 2)

        # 앞발
        pygame.draw.ellipse(screen, colors["body"],
                          (x - body_size // 3, y + body_size // 4, 10, 6))
        pygame.draw.ellipse(screen, colors["body"],
                          (x + body_size // 3 - 10, y + body_size // 4, 10, 6))

        # 머리
        head_size = int(body_size * 0.8)
        head_y = y - body_size // 2
        pygame.draw.circle(screen, colors["body"], (int(x), int(head_y)), head_size // 2)

        # 귀
        ear_size = 7
        pygame.draw.polygon(screen, colors["body"], [
            (x - head_size // 3, head_y - head_size // 4),
            (x - head_size // 3, head_y - head_size // 2 - ear_size),
            (x - head_size // 3 + ear_size, head_y - head_size // 4),
        ])
        pygame.draw.polygon(screen, colors["body"], [
            (x + head_size // 3, head_y - head_size // 4),
            (x + head_size // 3, head_y - head_size // 2 - ear_size),
            (x + head_size // 3 - ear_size, head_y - head_size // 4),
        ])

        # 눈 (감은 눈 - 앉아서 쉬는 중)
        eye_y = head_y - 1
        pygame.draw.arc(screen, (40, 40, 40), (x - 8, eye_y - 2, 6, 4), 0, math.pi, 2)
        pygame.draw.arc(screen, (40, 40, 40), (x + 2, eye_y - 2, 6, 4), 0, math.pi, 2)

        # 코
        pygame.draw.polygon(screen, (255, 150, 150), [
            (x, head_y + 2),
            (x - 2, head_y + 5),
            (x + 2, head_y + 5),
        ])

        # 꼬리 (몸 옆에)
        tail_wave = math.sin(self.effect_timer * 2) * 3
        pygame.draw.arc(screen, colors["body"],
                       (x + body_size // 3, y - body_size // 4, 20, 30 + tail_wave),
                       -0.5, math.pi * 0.8, 4)

    def _draw_robot(self, screen, x, y):
        """로봇 그리기"""
        colors = self.colors
        bounce = 0

        if self.vx != 0 or self.vy != 0:
            bounce = math.sin(self.animation_frame * math.pi) * 1

        # 글로우 효과
        if self.config.get("has_glow"):
            glow_alpha = int(100 + 50 * math.sin(self.effect_timer * 5))
            glow_surf = pygame.Surface((self.width + 20, self.height + 20), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*colors["accent"], glow_alpha // 3),
                           (0, 0, self.width + 20, self.height + 20), border_radius=10)
            screen.blit(glow_surf, (x - self.width // 2 - 10, y - self.height // 2 - 10 - bounce))

        # 몸통 (사각형)
        body_rect = pygame.Rect(
            x - self.width // 2,
            y - self.height // 3 - bounce,
            self.width,
            self.height * 2 // 3
        )
        pygame.draw.rect(screen, colors["body"], body_rect, border_radius=5)
        pygame.draw.rect(screen, colors["accent"], body_rect, 2, border_radius=5)

        # 가슴 패널
        panel_rect = pygame.Rect(
            x - self.width // 3,
            y - self.height // 4 - bounce,
            self.width * 2 // 3,
            self.height // 4
        )
        pygame.draw.rect(screen, (50, 50, 60), panel_rect)
        # 패널 조명
        light_x = x - self.width // 4
        for i in range(3):
            light_color = colors["accent"] if (int(self.effect_timer * 3) + i) % 3 == 0 else (60, 60, 70)
            pygame.draw.circle(screen, light_color,
                             (int(light_x + i * 10), int(y - self.height // 6 - bounce)), 3)

        # 머리 (사각형)
        head_w = int(self.width * 0.8)
        head_h = int(self.height * 0.35)
        head_rect = pygame.Rect(
            x - head_w // 2,
            y - self.height // 2 - head_h // 2 - bounce,
            head_w,
            head_h
        )
        pygame.draw.rect(screen, colors["body"], head_rect, border_radius=3)
        pygame.draw.rect(screen, colors["accent"], head_rect, 2, border_radius=3)

        # 안테나
        antenna_y = y - self.height // 2 - head_h - bounce
        pygame.draw.line(screen, colors["body"],
                        (x, y - self.height // 2 - head_h // 2 - bounce),
                        (x, antenna_y - 5), 2)
        # 안테나 끝 (깜빡임)
        blink = int(self.effect_timer * 5) % 2 == 0
        pygame.draw.circle(screen, colors["accent"] if blink else (100, 100, 100),
                          (int(x), int(antenna_y - 5)), 3)

        # 눈 (LED)
        eye_y = y - self.height // 2 - bounce
        eye_glow = 255 if blink else 150
        pygame.draw.rect(screen, (*colors["eye"][:2], eye_glow),
                        (x - 10, eye_y - 3, 8, 6))
        pygame.draw.rect(screen, (*colors["eye"][:2], eye_glow),
                        (x + 2, eye_y - 3, 8, 6))

        # 다리 (기계식)
        leg_y = y + self.height // 3 - bounce
        leg_offset = math.sin(self.animation_frame * math.pi / 2) * 3 if (self.vx != 0 or self.vy != 0) else 0
        for i, lx in enumerate([x - 6, x + 6]):
            offset = leg_offset if i % 2 == 0 else -leg_offset
            pygame.draw.line(screen, colors["body"],
                           (lx, leg_y), (lx, leg_y + 10), 4)
            pygame.draw.rect(screen, colors["accent"],
                           (lx - 4, leg_y + 10 + abs(offset), 8, 4))

    def _draw_speech_bubble(self, screen, x, y):
        """말풍선 그리기"""
        if not self.speech_bubble:
            return

        # 한글 폰트 로드 (pygame.freetype 사용)
        font = None
        font_size = 14

        # 1차 시도: resource_path로 폰트 로드
        try:
            font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
            if os.path.exists(font_path):
                font = pygame.freetype.Font(font_path, font_size)
        except Exception:
            pass

        # 2차 시도: 시스템 폰트 (macOS/Windows)
        if font is None:
            try:
                # macOS
                if os.path.exists("/System/Library/Fonts/AppleSDGothicNeo.ttc"):
                    font = pygame.freetype.Font("/System/Library/Fonts/AppleSDGothicNeo.ttc", font_size)
                # Windows
                elif os.path.exists("C:/Windows/Fonts/malgun.ttf"):
                    font = pygame.freetype.Font("C:/Windows/Fonts/malgun.ttf", font_size)
            except Exception:
                pass

        # 3차 시도: 기본 폰트
        if font is None:
            try:
                font = pygame.freetype.SysFont("malgungothic", font_size)
            except Exception:
                font = pygame.freetype.SysFont(None, font_size)

        # 텍스트 렌더링
        text_surface, text_rect = font.render(self.speech_bubble, (40, 40, 40))
        text_w = text_rect.width + 16
        text_h = text_rect.height + 10

        bubble_x = x - text_w // 2
        bubble_y = y - self.height - 25

        # 화면 밖으로 나가지 않게 조정
        bubble_x = max(5, min(SCREEN_WIDTH - text_w - 5, bubble_x))

        # 말풍선 배경
        bubble_surf = pygame.Surface((text_w, text_h + 8), pygame.SRCALPHA)
        pygame.draw.rect(bubble_surf, (255, 255, 255, 240),
                        (0, 0, text_w, text_h), border_radius=8)
        pygame.draw.rect(bubble_surf, (80, 80, 80),
                        (0, 0, text_w, text_h), 2, border_radius=8)

        # 꼬리
        pygame.draw.polygon(bubble_surf, (255, 255, 255, 240), [
            (text_w // 2 - 6, text_h),
            (text_w // 2 + 6, text_h),
            (text_w // 2, text_h + 8),
        ])
        pygame.draw.line(bubble_surf, (80, 80, 80),
                        (text_w // 2 - 6, text_h), (text_w // 2, text_h + 8), 2)
        pygame.draw.line(bubble_surf, (80, 80, 80),
                        (text_w // 2 + 6, text_h), (text_w // 2, text_h + 8), 2)

        screen.blit(bubble_surf, (bubble_x, bubble_y))
        screen.blit(text_surface, (bubble_x + 8, bubble_y + 5))

    def get_rect(self):
        """충돌 렉트 반환"""
        return pygame.Rect(
            self.x - self.width // 2,
            self.y - self.height // 2,
            self.width,
            self.height
        )

    def can_talk(self):
        """대화 가능 여부 체크 (사람형 NPC만 대화 가능)"""
        # 동물은 대화 불가
        if self.type in [NPCType.DOG, NPCType.CAT]:
            return False
        # 현재 대화 중이면 불가
        if self.is_talking:
            return False
        return True

    def start_dialogue(self):
        """대화 시작 - 랜덤 대사 선택"""
        if not self.can_talk():
            return None

        self.is_talking = True
        self.dialogue_timer = 4.0  # 4초간 대화 유지

        # NPC 타입별 대사 선택
        dialogue = self._get_random_dialogue()

        if dialogue:
            self.speech_bubble = dialogue
            self.speech_timer = 4.0
            self.last_dialogue = dialogue

            # 대화 중 정지
            self.state = "chatting"
            self.idle_duration = 4.0
            self.state_timer = 0
            self.vx = 0
            self.vy = 0

        return dialogue

    def _get_random_dialogue(self):
        """NPC 타입에 맞는 랜덤 대사 반환"""
        # 타입별 전용 대사가 있는 경우
        type_dialogues = {
            NPCType.CHILD: "child",
            NPCType.OLD_MAN: "old_man",
            NPCType.MERCHANT: "merchant",
            NPCType.ROBOT: "robot",
        }

        dialogue_pool = []

        # 전용 대사가 있으면 전용 대사에서 선택
        if self.type in type_dialogues:
            category = type_dialogues[self.type]
            dialogue_pool = NPC_DIALOGUES.get(category, [])
        else:
            # 일반 주민은 모든 카테고리에서 랜덤
            all_categories = ["game_tips", "world_lore", "daily_life"]
            category = random.choice(all_categories)
            dialogue_pool = NPC_DIALOGUES.get(category, [])

        if not dialogue_pool:
            return "..."

        # 마지막 대화와 다른 것 선택 시도
        available = [d for d in dialogue_pool if d != self.last_dialogue]
        if not available:
            available = dialogue_pool

        return random.choice(available)

    def end_dialogue(self):
        """대화 종료"""
        self.is_talking = False
        self.dialogue_timer = 0


class NPCManager:
    """NPC 관리자"""

    def __init__(self):
        self.npcs = []
        self.max_npcs = 15
        self.spawn_timer = 0
        self.spawn_interval = 2.0

    def initialize(self, downtown_map, stage_number=1):
        """NPC 초기화 - 맵에 맞게 생성"""
        self.npcs.clear()

        # 스테이지에 따른 NPC 수
        base_count = 5 + stage_number
        npc_count = min(base_count, self.max_npcs)

        # NPC 타입 가중치
        type_weights = {
            NPCType.CITIZEN_MALE: 20,
            NPCType.CITIZEN_FEMALE: 20,
            NPCType.DOG: 15,
            NPCType.CAT: 15,
            NPCType.CHILD: 10,
            NPCType.ROBOT: 10,
            NPCType.OLD_MAN: 8,
            NPCType.MERCHANT: 2,
        }

        # 가중치에 따른 타입 리스트
        type_list = []
        for npc_type, weight in type_weights.items():
            type_list.extend([npc_type] * weight)

        # NPC 생성
        for _ in range(npc_count):
            npc_type = random.choice(type_list)

            # 랜덤 위치 (도로나 바닥 위)
            attempts = 0
            while attempts < 50:
                x = random.randint(TILE_SIZE * 2, (MAP_WIDTH - 2) * TILE_SIZE)
                y = random.randint(TILE_SIZE * 2, (MAP_HEIGHT - 2) * TILE_SIZE)

                if downtown_map.is_walkable(x, y):
                    npc = NPC(npc_type, x, y)
                    self.npcs.append(npc)
                    break

                attempts += 1

    def update(self, dt, downtown_map):
        """모든 NPC 업데이트"""
        for npc in self.npcs:
            npc.update(dt, downtown_map)

        # 동적 스폰 (선택적)
        # self._try_spawn(dt, downtown_map)

    def _try_spawn(self, dt, downtown_map):
        """동적 NPC 스폰 시도"""
        if len(self.npcs) >= self.max_npcs:
            return

        self.spawn_timer += dt
        if self.spawn_timer < self.spawn_interval:
            return

        self.spawn_timer = 0

        if random.random() > 0.3:
            return

        # 랜덤 타입과 위치로 스폰
        npc_types = list(NPC_CONFIG.keys())
        npc_type = random.choice(npc_types)

        # 화면 가장자리에서 스폰
        edge = random.randint(0, 3)
        if edge == 0:  # 상단
            x = random.randint(TILE_SIZE * 2, (MAP_WIDTH - 2) * TILE_SIZE)
            y = TILE_SIZE * 2
        elif edge == 1:  # 하단
            x = random.randint(TILE_SIZE * 2, (MAP_WIDTH - 2) * TILE_SIZE)
            y = (MAP_HEIGHT - 2) * TILE_SIZE
        elif edge == 2:  # 좌측
            x = TILE_SIZE * 2
            y = random.randint(TILE_SIZE * 2, (MAP_HEIGHT - 2) * TILE_SIZE)
        else:  # 우측
            x = (MAP_WIDTH - 2) * TILE_SIZE
            y = random.randint(TILE_SIZE * 2, (MAP_HEIGHT - 2) * TILE_SIZE)

        if downtown_map.is_walkable(x, y):
            npc = NPC(npc_type, x, y)
            self.npcs.append(npc)

    def draw(self, screen, camera_offset=(0, 0)):
        """모든 NPC 그리기 (Y좌표 정렬)"""
        # Y좌표 기준 정렬 (깊이 표현)
        sorted_npcs = sorted(self.npcs, key=lambda n: n.y)

        for npc in sorted_npcs:
            npc.draw(screen, camera_offset)

    def get_npcs_in_range(self, x, y, radius):
        """범위 내 NPC 목록"""
        result = []
        for npc in self.npcs:
            dist = math.sqrt((npc.x - x) ** 2 + (npc.y - y) ** 2)
            if dist <= radius:
                result.append(npc)
        return result

    def get_talkable_npc_near(self, x, y, radius=60):
        """대화 가능한 가장 가까운 NPC 반환"""
        nearby = self.get_npcs_in_range(x, y, radius)
        talkable = [npc for npc in nearby if npc.can_talk()]

        if not talkable:
            return None

        # 가장 가까운 NPC 반환
        talkable.sort(key=lambda n: math.sqrt((n.x - x) ** 2 + (n.y - y) ** 2))
        return talkable[0]

    def try_talk_to_npc(self, x, y, radius=60):
        """NPC에게 말 걸기 시도 - 성공 시 대사 반환"""
        npc = self.get_talkable_npc_near(x, y, radius)
        if npc:
            return npc.start_dialogue()
        return None

    def trigger_reactions(self, player_x, player_y, radius=50):
        """플레이어 근처 NPC 반응"""
        nearby = self.get_npcs_in_range(player_x, player_y, radius)

        for npc in nearby:
            # 강아지는 플레이어 쪽으로 다가옴
            if npc.type == NPCType.DOG and random.random() < 0.1:
                npc.target_x = player_x + random.randint(-30, 30)
                npc.target_y = player_y + random.randint(-30, 30)
                if random.random() < 0.3:
                    npc.speech_bubble = "멍멍!"
                    npc.speech_timer = 1.5

            # 고양이는 도망감
            elif npc.type == NPCType.CAT and npc.state != "sitting":
                if random.random() < 0.2:
                    dx = npc.x - player_x
                    dy = npc.y - player_y
                    dist = math.sqrt(dx * dx + dy * dy) or 1
                    npc.target_x = npc.x + (dx / dist) * 100
                    npc.target_y = npc.y + (dy / dist) * 100
