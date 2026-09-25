'use strict';
// 極簡 DOM 替身：供測試在 Node 內驅動**完整**之助手產物（含 DOM 層）。
//
// 目的：瀏覽器不可得時（本工作區之外部行程存取受限），仍能對 dist/app.js 做端到端之
// 冒煙測試——掛載、逐步導覽、作答、摘要與 JSON 產出皆須無例外。
// 本替身只實作助手用到的那一小塊 DOM，**不是**通用之 DOM 實作。

function createDom() {
  let documentRef = null;

  function isText(node) {
    return node && node.nodeType === 3;
  }

  function TextNode(value) {
    this.nodeType = 3;
    this.nodeValue = String(value);
    this.parentNode = null;
  }

  function Element(tag) {
    this.nodeType = 1;
    this.tagName = String(tag).toUpperCase();
    this.childNodes = [];
    this.parentNode = null;
    this.attributes = {};
    this.style = {};
    this.className = '';
    this.listeners = {};
    this.value = '';
    this.checked = false;
    this.disabled = false;
    this.readOnly = false;
    this.selected = false;
    this.href = '';
    this.target = '';
    this.title = '';
    this.type = '';
    this.onclick = null;
    this.onchange = null;
    this.onblur = null;
    this.onkeydown = null;
  }

  Object.defineProperty(Element.prototype, 'firstChild', {
    get: function () { return this.childNodes.length > 0 ? this.childNodes[0] : null; },
  });

  Object.defineProperty(Element.prototype, 'textContent', {
    get: function () {
      let out = '';
      for (const child of this.childNodes) {
        out += isText(child) ? child.nodeValue : child.textContent;
      }
      return out;
    },
    set: function (value) {
      this.childNodes = [];
      this.appendChild(new TextNode(value));
    },
  });

  Element.prototype.appendChild = function (child) {
    if (child.parentNode) child.parentNode.removeChild(child);
    child.parentNode = this;
    this.childNodes.push(child);
    return child;
  };

  Element.prototype.removeChild = function (child) {
    const index = this.childNodes.indexOf(child);
    if (index >= 0) this.childNodes.splice(index, 1);
    child.parentNode = null;
    return child;
  };

  Element.prototype.setAttribute = function (name, value) {
    this.attributes[name] = String(value);
    if (name === 'class') this.className = String(value);
  };

  Element.prototype.getAttribute = function (name) {
    return Object.prototype.hasOwnProperty.call(this.attributes, name)
      ? this.attributes[name] : null;
  };

  Element.prototype.focus = function () { documentRef.activeElement = this; };
  Element.prototype.blur = function () { if (documentRef.activeElement === this) documentRef.activeElement = documentRef.body; };
  // 忠實模擬瀏覽器之行為：點擊核取項即先翻轉其狀態，再派送 click 處理器。
  // （若略去此翻轉，`onclick` 內讀到的 `checked` 會是舊值——本專案的「以推薦值補齊」
  //   核取項即靠 `checked` 決定補或撤，故非模擬不可。）
  Element.prototype.click = function () {
    if (this.type === 'checkbox') {
      this.checked = !this.checked;
    } else if (this.type === 'radio') {
      // `name` 是 DOM 屬性（本專案以 `input.name = …` 設定），非 setAttribute。
      const group = this.name || this.getAttribute('name');
      if (group && documentRef) {
        const self = this;
        walk(documentRef.body, function (node) {
          if (node.nodeType !== 1 || node === self) return;
          if (node.type === 'radio' && node.getAttribute('name') === group) node.checked = false;
        });
      }
      this.checked = true;
    }
    if (typeof this.onclick === 'function') this.onclick();
  };
  Element.prototype.select = function () { documentRef.activeElement = this; };

  Element.prototype.querySelector = function (selector) {
    const match = /^\[data-focus-key="(.+)"\]$/.exec(selector);
    if (!match) return null;
    const wanted = match[1];
    let found = null;
    walk(this, function (node) {
      if (found) return;
      if (node.getAttribute && node.getAttribute('data-focus-key') === wanted) found = node;
    });
    return found;
  };

  Element.prototype.querySelectorAll = function (selector) {
    const className = selector.charAt(0) === '.' ? selector.slice(1) : null;
    const results = [];
    if (!className) return results;
    walk(this, function (node) {
      if (node.nodeType !== 1) return;
      const classes = String(node.className).split(/\s+/);
      if (classes.indexOf(className) >= 0) results.push(node);
    });
    return results;
  };

  function walk(node, visit) {
    visit(node);
    if (node.nodeType !== 1) return;
    for (const child of node.childNodes.slice()) walk(child, visit);
  }

  const body = new Element('body');
  const documentElement = new Element('html');
  const root = new Element('div');
  root.setAttribute('id', 'vca-root');
  body.appendChild(root);

  documentRef = {
    nodeType: 9,
    title: '唯音輸入法配置助手',
    body: body,
    documentElement: documentElement,
    activeElement: body,
    createElement: function (tag) { return new Element(tag); },
    createTextNode: function (value) { return new TextNode(value); },
    getElementById: function (id) {
      return id === 'vca-root' ? root : null;
    },
    execCommand: function () { return false; },
  };

  const windowRef = {
    document: documentRef,
    location: { search: '', pathname: '/assistant/index.html', hash: '' },
    history: { replaceState: function () { /* 測試中不追蹤網址 */ } },
    onkeydown: null,
    setTimeout: function () { return 0; },
    open: function () { return null; },
    navigator: { language: 'zh-Hant-TW', userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' },
  };

  return { document: documentRef, window: windowRef, root: root, Element: Element, walk: walk };
}

/// 把替身裝進當前全域（供產物以瀏覽器之方式取得 document／window／navigator）。
/// 註：Node 之 `globalThis.navigator` 是唯讀之 getter，故一律以 `defineProperty` 覆寫。
function installDom(dom) {
  const define = function (name, value) {
    Object.defineProperty(globalThis, name, {
      value: value, writable: true, configurable: true, enumerable: true,
    });
  };
  define('document', dom.document);
  define('window', dom.window);
  define('navigator', dom.window.navigator);
  return dom;
}

function findByClass(root, className) {
  return root.querySelectorAll('.' + className);
}

function findByTag(root, tag) {
  const wanted = String(tag).toUpperCase();
  const results = [];
  const walk = function (node) {
    if (node.nodeType === 1 && node.tagName === wanted) results.push(node);
    if (node.nodeType !== 1) return;
    for (const child of node.childNodes) walk(child);
  };
  walk(root);
  return results;
}

function textOfButton(node) {
  return node ? node.textContent : '';
}

function findButtonByText(root, text) {
  const buttons = findByTag(root, 'button');
  for (const button of buttons) {
    if (button.textContent === text) return button;
  }
  return null;
}

module.exports = { createDom, installDom, findByClass, findByTag, findButtonByText, textOfButton };
