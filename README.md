# NotesPlus

macOS 메모 앱(Apple Notes)에 편집 기능을 더해주는 메뉴 막대 앱. 메모 앱 자체는 건드리지 않고 손쉬운 사용(Accessibility) API로 동작한다.

## 기능

- **`/` 명령**: 제목·목록·체크리스트·표 등 서식, 템플릿 삽입, macOS 글쓰기 도구(요약·교정·재작성 등)
- **마크다운 단축 입력**: `# `, `- `, `1. `, `[] `, `> `, `**굵게**`, `~~취소선~~` 등
- **서식 바**: 커서를 따라다니며 볼드·이탤릭·밑줄·취소선 상태 표시와 토글, 글자색, 글쓰기 도구
- **노트 링크와 백링크**: `[[`로 메모 링크 삽입, 현재 메모를 링크한 메모 목록 표시
- **템플릿**: `~/Library/Application Support/notes-plus/templates`의 `.md`/`.txt` 파일

## 요구 사항

- macOS 14 이상 (macOS 27 메모 앱에서 확인)
- 손쉬운 사용 권한 (필수)
- 전체 디스크 접근 권한 (백링크용, 선택)
- 글쓰기 도구는 Apple Intelligence가 켜져 있어야 동작

## 빌드

```sh
scripts/build.sh          # build/NotesPlus.app 생성
open build/NotesPlus.app
```

서명 인증서는 `SIGN_ID` 환경 변수나 `git config notesplus.signId <인증서 SHA-1>`(로컬 전용)로 지정한다. 지정하지 않으면 ad-hoc 서명이며, 이 경우 빌드할 때마다 손쉬운 사용 권한을 다시 켜야 한다.

## 릴리스

```sh
scripts/release.sh 0.2.0
```

`Info.plist` 버전 갱신 → 커밋 → `v0.2.0` 태그 → 푸시 → GitHub Release에 앱 zip 첨부. 버전은 [Semantic Versioning](https://semver.org/lang/ko/)을 따른다.

앱 메뉴의 "업데이트 확인…"과 하루 한 번 자동 확인으로 [Sparkle](https://sparkle-project.org) 업데이트를 받는다. EdDSA 개인 키는 `generate_keys --account notes-plus`로 로그인 키체인에 있으며, 잃어버리면 기존 사용자에게 업데이트를 보낼 수 없으므로 `generate_keys --account notes-plus -x <파일>`로 백업해 둔다.

배포 zip은 공증(notarization)되지 않았으므로 다른 Mac에서는 처음 실행 시 Gatekeeper 경고가 뜬다.

## 라이선스

MIT
