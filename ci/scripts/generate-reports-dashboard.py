#!/usr/bin/env python3
import json
import os
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo

# Базовая директория, где лежит сгенерированный сайт с отчётами
BASE_DIR = "repo-pages/public"

# Часовой пояс для отображения дат публикации
TIMEZONE = ZoneInfo("Europe/Moscow")


def read_published_at(path: str) -> str:
    """
    Читает дату публикации из файла .published_at
    и возвращает её в человекочитаемом формате МСК.
    """
    meta = os.path.join(path, ".published_at")
    if not os.path.exists(meta):
        return ""

    try:
        raw = Path(meta).read_text(encoding="utf-8").strip()
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        dt = datetime.fromisoformat(raw)
        return dt.astimezone(TIMEZONE).strftime("%Y-%m-%d %H:%M МСК")
    except Exception:
        return ""


def latest_exists(env: str, suite: str) -> bool:
    """
    Проверяет, существует ли latest-отчёт для указанного окружения и набора тестов.
    """
    full = os.path.join(BASE_DIR, env, suite)
    return os.path.isdir(full) and os.path.exists(os.path.join(full, "index.html"))


def list_archive(env: str, suite: str):
    """
    Собирает список архивных отчётов для указанного окружения и набора тестов.

    Ожидается структура:
      repo-pages/public/<env>/archive/<suite>-<pipeline_id>/index.html
    """
    archive_dir = os.path.join(BASE_DIR, env, "archive")
    if not os.path.isdir(archive_dir):
        return []

    prefix = f"{suite}-"
    items = []

    for name in os.listdir(archive_dir):
        full = os.path.join(archive_dir, name)
        if (
            name.startswith(prefix)
            and os.path.isdir(full)
            and os.path.exists(os.path.join(full, "index.html"))
        ):
            published = read_published_at(full)
            pipeline_id = name.rsplit("-", 1)[-1]
            items.append({
                "env": env,
                "suite": suite,
                "name": name,
                "pipeline_id": pipeline_id,
                "published_at": published,
                "url": f"./{env}/archive/{name}/index.html",
            })

    # Сортировка архивов по pipeline id в порядке убывания
    def sort_key(item):
        try:
            return int(item["pipeline_id"])
        except Exception:
            return -1

    items.sort(key=sort_key, reverse=True)
    return items


def latest_card(env: str, suite: str):
    """
    Формирует данные для карточки latest.

    Дополнительно подтягивает информацию о последнем архивном отчёте:
    - id последнего pipeline
    - дату публикации последнего архива
    - ссылку на последний архив
    """
    if not latest_exists(env, suite):
        return None

    archive_items = list_archive(env, suite)
    last_archive = archive_items[0] if archive_items else None

    return {
        "env": env,
        "suite": suite,
        "title": f"{env} / {suite}",
        "url": f"./{env}/{suite}/index.html",
        "last_archive_published_at": last_archive["published_at"] if last_archive else "",
        "last_pipeline_id": last_archive["pipeline_id"] if last_archive else "",
        "last_archive_name": last_archive["name"] if last_archive else "",
        "archive_count": len(archive_items),
        "archive_url": last_archive["url"] if last_archive else "",
    }


def collect_data():
    """
    Собирает все данные для страницы:
    - latest-карточки
    - архивные отчёты
    - агрегированную статистику
    """
    latest = []
    archive = []

    for env, suites in (
        ("dev", ["smoke"]),
        ("test-stand", ["smoke", "regression"]),
    ):
        for suite in suites:
            archive_items = list_archive(env, suite)
            archive.extend(archive_items)

            card = latest_card(env, suite)
            if card:
                latest.append(card)

    totals = {
        "latest_count": len(latest),
        "archive_count": len(archive),
        "dev_smoke_count": len([x for x in archive if x["env"] == "dev" and x["suite"] == "smoke"]),
        "test_smoke_count": len([x for x in archive if x["env"] == "test-stand" and x["suite"] == "smoke"]),
        "test_regression_count": len([x for x in archive if x["env"] == "test-stand" and x["suite"] == "regression"]),
    }

    return latest, archive, totals


def render_html(latest, archive, totals):
    """
    Генерирует итоговый HTML дашборда.
    """
    html = '''<!doctype html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>API Autotests Reports</title>
  <style>
    :root {
      --bg: #f6f8fb;
      --card: #ffffff;
      --line: #e5e7eb;
      --text: #111827;
      --muted: #6b7280;
      --accent: #2563eb;
      --accent-soft: #eff6ff;
      --shadow: 0 10px 28px rgba(15, 23, 42, 0.08);
      --radius: 18px;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      font-family: Inter, Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
    }

    .wrap {
      max-width: 1240px;
      margin: 0 auto;
      padding: 36px 20px 56px;
    }

    .hero {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      gap: 20px;
      margin-bottom: 26px;
      flex-wrap: wrap;
    }

    .hero h1 {
      margin: 0 0 10px;
      font-size: 34px;
      line-height: 1.1;
      letter-spacing: -0.02em;
    }

    .hero p {
      margin: 0;
      color: var(--muted);
      max-width: 760px;
      font-size: 15px;
      line-height: 1.5;
    }

    .section { margin-top: 30px; }

    .section h2 {
      margin: 0 0 16px;
      font-size: 22px;
      letter-spacing: -0.01em;
    }

    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 14px;
    }

    .summary-card {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      padding: 18px;
    }

    .summary-label {
      font-size: 13px;
      color: var(--muted);
      margin-bottom: 8px;
    }

    .summary-value {
      font-size: 28px;
      font-weight: 800;
      line-height: 1;
      margin-bottom: 6px;
    }

    .summary-sub {
      font-size: 13px;
      color: var(--muted);
    }

    .cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 16px;
    }

    .card {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      padding: 18px;
      color: inherit;
      transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
    }

    .card:hover {
      transform: translateY(-2px);
      border-color: #bfd3ff;
      box-shadow: 0 12px 28px rgba(37, 99, 235, 0.12);
    }

    .card-links {
      display: flex;
      gap: 10px;
      margin-top: 14px;
      flex-wrap: wrap;
    }

    .pill {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 999px;
      background: var(--accent-soft);
      color: var(--accent);
      font-size: 12px;
      font-weight: 700;
      margin-bottom: 12px;
      text-transform: lowercase;
    }

    .card-title {
      font-size: 18px;
      font-weight: 800;
      margin: 0 0 8px;
      line-height: 1.3;
    }

    .card-meta {
      font-size: 14px;
      color: var(--muted);
      margin: 6px 0;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 10px 14px;
      border-radius: 12px;
      text-decoration: none;
      font-size: 14px;
      font-weight: 700;
      border: 1px solid var(--line);
      background: #fff;
      color: var(--text);
    }

    .btn-primary {
      background: var(--accent);
      border-color: var(--accent);
      color: #fff;
    }

    .toolbar {
      display: grid;
      grid-template-columns: 180px 180px minmax(220px, 1fr);
      gap: 12px;
      margin-bottom: 16px;
    }

    .toolbar select,
    .toolbar input {
      width: 100%;
      border: 1px solid var(--line);
      background: #fff;
      border-radius: 12px;
      padding: 12px 14px;
      font-size: 14px;
      color: var(--text);
      outline: none;
    }

    .toolbar select:focus,
    .toolbar input:focus {
      border-color: #93c5fd;
      box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.12);
    }

    .table-wrap {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      overflow: hidden;
    }

    table {
      width: 100%;
      border-collapse: collapse;
    }

    th, td {
      padding: 14px 16px;
      text-align: left;
      border-bottom: 1px solid var(--line);
      font-size: 14px;
      vertical-align: middle;
    }

    th {
      background: #fafbff;
      color: var(--muted);
      font-weight: 700;
    }

    tr:last-child td { border-bottom: none; }

    .link {
      color: var(--accent);
      text-decoration: none;
      font-weight: 700;
    }

    .link:hover { text-decoration: underline; }
    .muted { color: var(--muted); }

    .empty {
      padding: 24px 16px;
      color: var(--muted);
    }

    .footer {
      margin-top: 20px;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.5;
    }

    @media (max-width: 860px) {
      .toolbar { grid-template-columns: 1fr; }
      .hero h1 { font-size: 28px; }
      th:nth-child(4), td:nth-child(4) { display: none; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <div>
        <h1>API Autotests Reports</h1>
        <p>Сводная страница для latest и archive отчётов. Отдельные прогоны разделены по окружениям и наборам тестов, архивные ссылки ведут на конкретные pipeline.</p>
      </div>
    </div>

    <section class="section">
      <h2>Summary</h2>
      <div class="summary-grid" id="summary-grid"></div>
    </section>

    <section class="section">
      <h2>Latest</h2>
      <div class="cards" id="latest-cards"></div>
    </section>

    <section class="section">
      <h2>Archive</h2>
      <div class="toolbar">
        <select id="env-filter">
          <option value="">Все окружения</option>
          <option value="dev">dev</option>
          <option value="test-stand">test-stand</option>
        </select>

        <select id="suite-filter">
          <option value="">Все наборы</option>
          <option value="smoke">smoke</option>
          <option value="regression">regression</option>
        </select>

        <input id="search-filter" type="text" placeholder="Поиск по pipeline id или имени архива">
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Окружение</th>
              <th>Набор</th>
              <th>Pipeline</th>
              <th>Дата публикации</th>
              <th>Отчёт</th>
            </tr>
          </thead>
          <tbody id="archive-body"></tbody>
        </table>
        <div class="empty" id="archive-empty" style="display:none;">Ничего не найдено по выбранным фильтрам.</div>
      </div>
    </section>

    <div class="footer">
      Latest используется как актуальная точка входа. Archive хранит постоянные ссылки на конкретные прогоны, которые используются в trend-графике Allure.
    </div>
  </div>

  <script>
    // Данные для отрисовки страницы, подставляются из Python
    const latestData = __LATEST_JSON__;
    const archiveData = __ARCHIVE_JSON__;
    const totals = __TOTALS_JSON__;

    // DOM-элементы для заполнения
    const summaryGrid = document.getElementById('summary-grid');
    const latestCards = document.getElementById('latest-cards');
    const archiveBody = document.getElementById('archive-body');
    const archiveEmpty = document.getElementById('archive-empty');

    // Элементы фильтрации архива
    const envFilter = document.getElementById('env-filter');
    const suiteFilter = document.getElementById('suite-filter');
    const searchFilter = document.getElementById('search-filter');

    function renderSummary() {
      // Рендерим верхние summary-карточки
      const items = [
        { label: 'Latest отчёты', value: totals.latest_count, sub: 'Актуальные точки входа' },
        { label: 'Все архивы', value: totals.archive_count, sub: 'Опубликованные архивные прогоны' },
        { label: 'dev smoke', value: totals.dev_smoke_count, sub: 'Архивы dev smoke' },
        { label: 'test smoke', value: totals.test_smoke_count, sub: 'Архивы test-stand smoke' },
        { label: 'test regression', value: totals.test_regression_count, sub: 'Архивы test-stand regression' }
      ];

      summaryGrid.innerHTML = '';
      items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'summary-card';
        div.innerHTML = `
          <div class="summary-label">${item.label}</div>
          <div class="summary-value">${item.value}</div>
          <div class="summary-sub">${item.sub}</div>
        `;
        summaryGrid.appendChild(div);
      });
    }

    function renderLatest() {
      // Рендерим карточки latest-отчётов
      latestCards.innerHTML = '';

      latestData.forEach(item => {
        const div = document.createElement('div');
        div.className = 'card';

        const archiveButton = item.archive_url
          ? `<a class="btn" href="${item.archive_url}">Последний архив</a>`
          : '';

        div.innerHTML = `
          <div class="pill">latest</div>
          <div class="card-title">${item.title}</div>
          <div class="card-meta">Последний pipeline: ${item.last_pipeline_id || '—'}</div>
          <div class="card-meta">Дата последнего архивного отчёта: ${item.last_archive_published_at || '—'}</div>
          <div class="card-meta">Архивов: ${item.archive_count}</div>
          <div class="card-links">
            <a class="btn btn-primary" href="${item.url}">Открыть latest</a>
            ${archiveButton}
          </div>
        `;
        latestCards.appendChild(div);
      });
    }

    function renderArchive() {
      // Рендерим таблицу archive с учётом выбранных фильтров
      const env = envFilter.value.trim().toLowerCase();
      const suite = suiteFilter.value.trim().toLowerCase();
      const q = searchFilter.value.trim().toLowerCase();

      const rows = archiveData.filter(item => {
        const envOk = !env || item.env === env;
        const suiteOk = !suite || item.suite === suite;
        const searchOk = !q
          || item.pipeline_id.toLowerCase().includes(q)
          || item.name.toLowerCase().includes(q);

        return envOk && suiteOk && searchOk;
      });

      archiveBody.innerHTML = '';

      if (!rows.length) {
        archiveEmpty.style.display = 'block';
        return;
      }

      archiveEmpty.style.display = 'none';

      rows.forEach(item => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${item.env}</td>
          <td>${item.suite}</td>
          <td>${item.pipeline_id}</td>
          <td class="muted">${item.published_at || '—'}</td>
          <td><a class="link" href="${item.url}">Открыть отчёт</a></td>
        `;
        archiveBody.appendChild(tr);
      });
    }

    // Подписываем фильтры на перерисовку таблицы
    envFilter.addEventListener('change', renderArchive);
    suiteFilter.addEventListener('change', renderArchive);
    searchFilter.addEventListener('input', renderArchive);

    // Первый рендер страницы
    renderSummary();
    renderLatest();
    renderArchive();
  </script>
</body>
</html>
'''
    html = html.replace("__LATEST_JSON__", json.dumps(latest, ensure_ascii=False))
    html = html.replace("__ARCHIVE_JSON__", json.dumps(archive, ensure_ascii=False))
    html = html.replace("__TOTALS_JSON__", json.dumps(totals, ensure_ascii=False))
    return html


def main():
    """
    Основная точка входа:
    - собираем данные
    - генерируем HTML
    - сохраняем итоговую страницу
    """
    latest, archive, totals = collect_data()
    out = Path(BASE_DIR) / "index.html"
    out.write_text(render_html(latest, archive, totals), encoding="utf-8")


if __name__ == "__main__":
    main()