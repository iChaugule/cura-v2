/**
 * Family ⇄ caregiver messaging with automatic translation.
 *
 * Everyone writes in their own language. Incoming messages are translated into
 * the reader's language as they arrive; outgoing ones are translated into the
 * recipient's language so both sides always read something natural. The
 * original is always one tap away.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  View, Text, StyleSheet, FlatList, Pressable, TextInput,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Avatar, EmptyState } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { languageLabel, languageNative, translateText } from '../../src/ai/cura';
import { clockTime, dayLabel, initials } from '../../src/lib/format';
import { useSpeech } from '../../src/lib/useSpeech';
import { useApp } from '../../src/state/AppContext';
import type { ChatMessage } from '../../src/models/types';

export default function Messages() {
  const { state, me, them, setTranslation, setTranslating, addMessage } = useApp();
  const [input, setInput] = useState('');
  const [showOriginal, setShowOriginal] = useState<Record<string, boolean>>({});
  const [autoTranslate, setAutoTranslate] = useState(true);
  const listRef = useRef<FlatList<ChatMessage>>(null);
  const inFlight = useRef<Set<string>>(new Set());
  const { speakingId, toggle } = useSpeech();

  const myLang = me?.language ?? 'en';
  // By person, not by role: two relatives in the same circle are both "family".
  const isMine = useCallback(
    (m: ChatMessage) => (state.live ? m.senderId === me?.id : m.senderRole === state.activeRole),
    [state.live, me?.id, state.activeRole],
  );
  const theirLang = them?.language ?? 'en';

  /** Translate anything the reader (or the recipient) cannot read yet. */
  const fillTranslations = useCallback(async () => {
    if (!autoTranslate) return;

    for (const m of state.messages) {
      // The language this message still needs.
      const needed = isMine(m) ? theirLang : myLang;
      if (!needed || needed === m.sourceLang) continue;
      if (m.translations[needed]) continue;

      const key = `${m.id}:${needed}`;
      if (inFlight.current.has(key)) continue;
      inFlight.current.add(key);

      setTranslating(m.id, true);
      try {
        const result = await translateText(m.text, needed);
        setTranslation(m.id, needed, result.translated, result.sourceLanguage || m.sourceLang);
      } catch {
        setTranslating(m.id, false);
      } finally {
        inFlight.current.delete(key);
      }
    }
  }, [state.messages, isMine, myLang, theirLang, autoTranslate, setTranslation, setTranslating]);

  useEffect(() => { fillTranslations(); }, [fillTranslations]);

  const send = () => {
    const text = input.trim();
    if (!text) return;
    addMessage(text);
    setInput('');
    setTimeout(() => listRef.current?.scrollToEnd({ animated: true }), 80);
  };

  if (!them) {
    return (
      <View style={s.screen}>
        <EmptyState
          icon="chatbubbles-outline"
          title="No one to message yet"
          body="Once a caregiver accepts, your conversation appears here."
        />
      </View>
    );
  }

  return (
    <View style={s.screen}>
      {/* Header */}
      <View style={s.header}>
        <Avatar
          initials={initials(them.name)}
          size={38}
          tone={them.role === 'caregiver' ? Colors.brown : Colors.textStrong}
        />
        <View style={{ flex: 1 }}>
          <Text style={s.headerName}>{them.name}</Text>
          <Text style={s.headerSub}>
            Writes in {languageLabel(theirLang)} · you read {languageLabel(myLang)}
          </Text>
        </View>
        <Pressable
          onPress={() => setAutoTranslate(v => !v)}
          accessibilityRole="switch"
          accessibilityState={{ checked: autoTranslate }}
          accessibilityLabel="Auto-translate"
          style={({ pressed }) => [
            s.translateToggle,
            autoTranslate && { backgroundColor: Colors.brown, borderColor: Colors.brown },
            pressed && { opacity: 0.8 },
          ]}
        >
          <Ionicons
            name="language"
            size={14}
            color={autoTranslate ? Colors.textOnBrown : Colors.textSecondary}
          />
          <Text style={[s.translateText, autoTranslate && { color: Colors.textOnBrown }]}>
            Auto
          </Text>
        </Pressable>
      </View>

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 88 : 0}
      >
        <FlatList
          ref={listRef}
          data={state.messages}
          keyExtractor={m => m.id}
          style={s.list}
          contentContainerStyle={s.listContent}
          showsVerticalScrollIndicator={false}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
          ListEmptyComponent={
            <EmptyState
              icon="hand-left-outline"
              title="Say hello"
              body={`Write in ${languageLabel(myLang)}, ${them.name.split(' ')[0]} reads it in ${languageLabel(theirLang)}.`}
            />
          }
          renderItem={({ item, index }) => {
            const prev = state.messages[index - 1];
            const newDay = !prev || dayLabel(prev.createdAt) !== dayLabel(item.createdAt);
            return (
              <>
                {newDay ? (
                  <View style={s.dayRow}>
                    <Text style={s.dayText}>{dayLabel(item.createdAt)}</Text>
                  </View>
                ) : null}
                <Bubble
                  message={item}
                  mine={isMine(item)}
                  showName={!isMine(item) && state.members.length > 2}
                  myLang={myLang}
                  theirLang={theirLang}
                  autoTranslate={autoTranslate}
                  showOriginal={!!showOriginal[item.id]}
                  onToggleOriginal={() =>
                    setShowOriginal(v => ({ ...v, [item.id]: !v[item.id] }))
                  }
                  speaking={speakingId === item.id}
                  onSpeak={(text, lang) => toggle(item.id, text, lang)}
                />
              </>
            );
          }}
        />

        <View style={s.composer}>
          <TextInput
            style={s.input}
            value={input}
            onChangeText={setInput}
            placeholder={`Message in ${languageNative(myLang)}…`}
            placeholderTextColor={Colors.textTertiary}
            multiline
            maxLength={800}
            onSubmitEditing={send}
            blurOnSubmit={false}
            accessibilityLabel="Write a message"
          />
          <Pressable
            onPress={send}
            disabled={!input.trim()}
            accessibilityRole="button"
            accessibilityLabel="Send message"
            style={({ pressed }) => [
              s.sendBtn,
              !input.trim() && { backgroundColor: Colors.textTertiary },
              pressed && { opacity: 0.8 },
            ]}
          >
            <Ionicons name="arrow-up" size={19} color={Colors.textOnBrown} />
          </Pressable>
        </View>
        {autoTranslate && theirLang !== myLang ? (
          <Text style={s.footNote}>
            Translated into {languageLabel(theirLang)} for {them.name.split(' ')[0]} automatically.
          </Text>
        ) : null}
      </KeyboardAvoidingView>
    </View>
  );
}

function Bubble({
  message, mine, myLang, theirLang, autoTranslate, showOriginal, onToggleOriginal,
  speaking, onSpeak, showName,
}: {
  message: ChatMessage;
  mine: boolean;
  showName?: boolean;
  myLang: string;
  theirLang: string;
  autoTranslate: boolean;
  showOriginal: boolean;
  onToggleOriginal: () => void;
  speaking: boolean;
  onSpeak: (text: string, lang: string) => void;
}) {
  // My own messages read in my language; theirs are translated into mine.
  const translated = mine ? undefined : message.translations[myLang];
  const isTranslated = !mine && !!translated && message.sourceLang !== myLang && autoTranslate;
  const display = isTranslated && !showOriginal ? translated! : message.text;
  const displayLang = isTranslated && !showOriginal ? myLang : message.sourceLang;

  // What the other side will see for my messages.
  const sentAs = mine ? message.translations[theirLang] : undefined;
  const pendingMine = mine && autoTranslate && theirLang !== message.sourceLang && !sentAs;

  return (
    <View style={[s.row, mine && { justifyContent: 'flex-end' }]}>
      <View style={[s.bubble, mine ? s.bubbleMine : s.bubbleTheirs]}>
        {showName ? <Text style={s.senderName}>{message.senderName}</Text> : null}
        <Text style={[s.text, mine && { color: Colors.textOnBrown }]}>{display}</Text>

        {isTranslated ? (
          <Pressable onPress={onToggleOriginal} hitSlop={6} accessibilityRole="button">
            <View style={s.translatedRow}>
              <Ionicons name="language" size={11} color={Colors.info} />
              <Text style={s.translatedText}>
                {showOriginal
                  ? `Showing ${languageLabel(message.sourceLang)} · tap for ${languageLabel(myLang)}`
                  : `Translated from ${languageLabel(message.sourceLang)} · tap for original`}
              </Text>
            </View>
          </Pressable>
        ) : null}

        {!mine && !translated && message.translating ? (
          <View style={s.translatingRow}>
            <ActivityIndicator size="small" color={Colors.textTertiary} />
            <Text style={s.translatingText}>Translating…</Text>
          </View>
        ) : null}

        {mine && sentAs ? (
          <View style={s.sentAsBox}>
            <Text style={s.sentAsLabel}>
              {them_label(theirLang)}
            </Text>
            <Text style={s.sentAsText}>{sentAs}</Text>
          </View>
        ) : pendingMine ? (
          <View style={s.translatingRow}>
            <ActivityIndicator size="small" color="rgba(253,248,242,0.7)" />
            <Text style={[s.translatingText, { color: 'rgba(253,248,242,0.75)' }]}>
              Translating for them…
            </Text>
          </View>
        ) : null}

        <View style={s.footer}>
          <Text style={[s.time, mine && { color: 'rgba(253,248,242,0.65)' }]}>
            {clockTime(message.createdAt)}
          </Text>
          <Pressable
            onPress={() => onSpeak(display, displayLang)}
            hitSlop={8}
            accessibilityRole="button"
            accessibilityLabel={speaking ? 'Stop reading aloud' : 'Read message aloud'}
          >
            <Ionicons
              name={speaking ? 'stop-circle' : 'volume-medium-outline'}
              size={15}
              color={mine ? 'rgba(253,248,242,0.75)' : Colors.textTertiary}
            />
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const them_label = (lang: string) => `THEY SEE (${languageLabel(lang).toUpperCase()})`;

const s = StyleSheet.create({
  senderName: { fontSize: 11, fontWeight: '700', color: Colors.textSecondary, marginBottom: 2 },
  screen: { flex: 1, backgroundColor: Colors.bgSunken },

  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: Spacing.md, paddingVertical: 9,
    backgroundColor: Colors.bgBase,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  headerName: { ...Type.subhead, color: Colors.textStrong },
  headerSub: { fontSize: 11.5, color: Colors.textSecondary, marginTop: 1 },
  translateToggle: {
    flexDirection: 'row', alignItems: 'center', gap: 4,
    paddingHorizontal: 10, paddingVertical: 6, borderRadius: Radius.pill,
    borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.surface,
  },
  translateText: { fontSize: 11.5, fontWeight: '700', color: Colors.textSecondary },

  list: { flex: 1 },
  listContent: { padding: Spacing.md, paddingBottom: Spacing.lg, gap: 8, flexGrow: 1 },

  dayRow: { alignItems: 'center', paddingVertical: 8 },
  dayText: {
    fontSize: 11, fontWeight: '600', color: Colors.textSecondary,
    backgroundColor: Colors.surfaceTinted, paddingHorizontal: 10, paddingVertical: 3,
    borderRadius: Radius.pill, overflow: 'hidden',
  },

  row: { flexDirection: 'row' },
  bubble: { maxWidth: '84%', paddingHorizontal: 13, paddingVertical: 9, borderRadius: Radius.lg, gap: 6 },
  bubbleTheirs: {
    backgroundColor: Colors.surface, borderBottomLeftRadius: 4,
    borderWidth: StyleSheet.hairlineWidth, borderColor: Colors.separator,
  },
  bubbleMine: { backgroundColor: Colors.brown, borderBottomRightRadius: 4 },
  text: { ...Type.body, fontSize: 15, color: Colors.textPrimary },

  translatedRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  translatedText: { fontSize: 10.5, color: Colors.info, flex: 1 },
  translatingRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  translatingText: { fontSize: 11, color: Colors.textTertiary },

  sentAsBox: {
    backgroundColor: 'rgba(253,248,242,0.15)', borderRadius: Radius.sm,
    paddingHorizontal: 8, paddingVertical: 6, gap: 2,
  },
  sentAsLabel: { fontSize: 9, fontWeight: '800', letterSpacing: 0.5, color: 'rgba(253,248,242,0.7)' },
  sentAsText: { fontSize: 13, color: Colors.textOnBrown, lineHeight: 18 },

  footer: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  time: { fontSize: 10, color: Colors.textTertiary },

  composer: {
    flexDirection: 'row', alignItems: 'flex-end', gap: 8,
    paddingHorizontal: Spacing.sm, paddingTop: Spacing.sm, paddingBottom: 4,
    backgroundColor: Colors.bgBase,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
  },
  input: {
    flex: 1, backgroundColor: Colors.surfaceRaised,
    borderWidth: 1, borderColor: Colors.border, borderRadius: Radius.xl,
    paddingHorizontal: 14, paddingVertical: 10,
    fontSize: 15, color: Colors.textStrong, maxHeight: 110,
  },
  sendBtn: {
    width: 38, height: 38, borderRadius: 19, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },
  footNote: {
    fontSize: 10.5, color: Colors.textTertiary, textAlign: 'center',
    paddingBottom: 8, paddingHorizontal: Spacing.md, backgroundColor: Colors.bgBase,
  },
});
