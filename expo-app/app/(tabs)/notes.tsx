/**
 * Notes — the running record of what changed.
 *
 * The caregiver writes what they saw and marks whether it is better, the same,
 * or worse. Family can read every note aloud and reply underneath, so a decline
 * never sits unnoticed.
 */
import { useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, Pressable, TextInput, Modal,
  KeyboardAvoidingView, Platform, Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import {
  Avatar, Button, Card, Chip, EmptyState, Field, Input, Pill, Segmented,
} from '../../src/components/ui';
import { Colors, Radius, Spacing, TrendColors, Type, type Trend } from '../../src/design/tokens';
import { polishNote } from '../../src/ai/cura';
import { friendlyError } from '../../src/ai/gemini';
import { initials, plainSpeech, relativeTime } from '../../src/lib/format';
import { useSpeech } from '../../src/lib/useSpeech';
import { useApp, useCareContext } from '../../src/state/AppContext';
import type { CareNote, NoteCategory } from '../../src/models/types';

const CATEGORIES: { value: NoteCategory; label: string; icon: string }[] = [
  { value: 'general', label: 'General', icon: 'ellipse-outline' },
  { value: 'appetite', label: 'Appetite', icon: 'restaurant-outline' },
  { value: 'hydration', label: 'Fluids', icon: 'water-outline' },
  { value: 'sleep', label: 'Sleep', icon: 'moon-outline' },
  { value: 'mood', label: 'Mood', icon: 'happy-outline' },
  { value: 'mobility', label: 'Mobility', icon: 'walk-outline' },
  { value: 'medication', label: 'Medication', icon: 'medkit-outline' },
  { value: 'skin', label: 'Skin', icon: 'bandage-outline' },
  { value: 'cognition', label: 'Memory', icon: 'bulb-outline' },
];

const TRENDS: { value: Trend; label: string }[] = [
  { value: 'better', label: 'Better' },
  { value: 'same', label: 'Same' },
  { value: 'worse', label: 'Worse' },
  { value: 'urgent', label: 'Urgent' },
];

type Filter = 'all' | 'concerns' | 'mine';

export default function Notes() {
  const { state, me, addNote, addComment, deleteNote } = useApp();
  const ctx = useCareContext();
  const { speakingId, toggle } = useSpeech();

  const [filter, setFilter] = useState<Filter>('all');
  const [composing, setComposing] = useState(false);
  const [openComments, setOpenComments] = useState<string | null>(null);

  const notes = useMemo(() => {
    if (filter === 'concerns') return state.notes.filter(n => n.trend === 'worse' || n.trend === 'urgent');
    if (filter === 'mine') return state.notes.filter(n => n.authorRole === state.activeRole);
    return state.notes;
  }, [state.notes, filter, state.activeRole]);

  const concerns = state.notes.filter(n => n.trend === 'worse' || n.trend === 'urgent').length;

  return (
    <View style={s.screen}>
      <View style={s.header}>
        <View style={{ flex: 1 }}>
          <Text style={s.headerTitle}>Notes</Text>
          <Text style={s.headerSub}>
            {state.notes.length} entries · {concerns} flagged as declining
          </Text>
        </View>
        <Pressable
          onPress={() => setComposing(true)}
          accessibilityRole="button"
          accessibilityLabel="Write a note"
          style={({ pressed }) => [s.addBtn, pressed && { opacity: 0.8 }]}
        >
          <Ionicons name="add" size={22} color={Colors.textOnBrown} />
        </Pressable>
      </View>

      <View style={s.filterBar}>
        <Segmented
          options={[
            { value: 'all', label: 'All' },
            { value: 'concerns', label: `Declining${concerns ? ` (${concerns})` : ''}` },
            { value: 'mine', label: 'Mine' },
          ]}
          value={filter}
          onChange={v => setFilter(v as Filter)}
        />
      </View>

      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        {notes.length === 0 ? (
          <EmptyState
            icon="document-text-outline"
            title={filter === 'all' ? 'No notes yet' : 'Nothing here'}
            body={
              filter === 'all'
                ? 'Notes are how the family knows what changed. Write the first one.'
                : 'Try a different filter.'
            }
            action={filter === 'all' ? 'Write a note' : 'Show all'}
            onAction={() => (filter === 'all' ? setComposing(true) : setFilter('all'))}
          />
        ) : (
          notes.map(note => (
            <NoteCard
              key={note.id}
              note={note}
              speaking={speakingId === note.id}
              onSpeak={() =>
                toggle(note.id, plainSpeech(`${note.title}. ${note.body}`), me?.language ?? 'en')
              }
              commentsOpen={openComments === note.id}
              onToggleComments={() => setOpenComments(openComments === note.id ? null : note.id)}
              onComment={body => addComment(note.id, body)}
              canDelete={state.live ? note.authorId === me?.id : note.authorRole === state.activeRole}
              onDelete={() => {
                if (Platform.OS === 'web') {
                  deleteNote(note.id);
                  return;
                }
                Alert.alert('Delete this note?', 'The family will no longer see it.', [
                  { text: 'Cancel', style: 'cancel' },
                  { text: 'Delete', style: 'destructive', onPress: () => deleteNote(note.id) },
                ]);
              }}
            />
          ))
        )}
        <View style={{ height: Spacing.xl }} />
      </ScrollView>

      <Composer
        visible={composing}
        onClose={() => setComposing(false)}
        onSave={input => {
          addNote(input);
          setComposing(false);
        }}
        pncName={state.pnc?.preferredName ?? 'them'}
        ctx={ctx}
      />
    </View>
  );
}

// ── Note card ───────────────────────────────────────────────

function NoteCard({
  note, speaking, onSpeak, commentsOpen, onToggleComments, onComment, canDelete, onDelete,
}: {
  note: CareNote;
  speaking: boolean;
  onSpeak: () => void;
  commentsOpen: boolean;
  onToggleComments: () => void;
  onComment: (body: string) => void;
  canDelete: boolean;
  onDelete: () => void;
}) {
  const [reply, setReply] = useState('');
  const tone = TrendColors[note.trend];
  const category = CATEGORIES.find(c => c.value === note.category);

  return (
    <Card style={s.note}>
      <View style={s.noteHead}>
        <View style={{ flex: 1, gap: 3 }}>
          <Text style={s.noteTitle}>{note.title}</Text>
          <View style={s.metaRow}>
            <Text style={s.metaText}>{note.authorName.split(' ')[0]}</Text>
            <Text style={s.dot}>·</Text>
            <Text style={s.metaText}>{relativeTime(note.createdAt)}</Text>
            <Text style={s.dot}>·</Text>
            <Text style={s.metaText}>{category?.label ?? note.category}</Text>
          </View>
        </View>
        <Pill label={tone.label} tone={tone} />
      </View>

      <Text style={s.noteBody}>{note.body}</Text>

      <View style={s.noteActions}>
        <Pressable
          onPress={onSpeak}
          accessibilityRole="button"
          accessibilityLabel={speaking ? 'Stop reading' : 'Read this note aloud'}
          style={({ pressed }) => [s.action, speaking && s.actionActive, pressed && { opacity: 0.7 }]}
        >
          <Ionicons
            name={speaking ? 'stop-circle' : 'volume-medium-outline'}
            size={15}
            color={speaking ? Colors.textOnBrown : Colors.brown}
          />
          <Text style={[s.actionText, speaking && { color: Colors.textOnBrown }]}>
            {speaking ? 'Stop' : 'Listen'}
          </Text>
        </Pressable>

        <Pressable
          onPress={onToggleComments}
          accessibilityRole="button"
          accessibilityLabel={
            note.comments.length
              ? `${note.comments.length} ${note.comments.length === 1 ? 'reply' : 'replies'}`
              : 'Reply to this note'
          }
          style={({ pressed }) => [s.action, pressed && { opacity: 0.7 }]}
        >
          <Ionicons name="chatbubble-outline" size={14} color={Colors.brown} />
          <Text style={s.actionText}>
            {note.comments.length ? `${note.comments.length} ${note.comments.length === 1 ? 'reply' : 'replies'}` : 'Reply'}
          </Text>
        </Pressable>

        {canDelete ? (
          <Pressable
            onPress={onDelete}
            accessibilityRole="button"
            accessibilityLabel="Delete note"
            style={({ pressed }) => [s.action, pressed && { opacity: 0.7 }]}
          >
            <Ionicons name="trash-outline" size={14} color={Colors.textTertiary} />
          </Pressable>
        ) : null}
      </View>

      {commentsOpen || note.comments.length ? (
        <View style={s.comments}>
          {note.comments.map(c => (
            <View key={c.id} style={s.comment}>
              <Avatar
                initials={initials(c.authorName)}
                size={26}
                tone={c.authorRole === 'family' ? Colors.textStrong : Colors.brown}
              />
              <View style={{ flex: 1 }}>
                <View style={s.commentHead}>
                  <Text style={s.commentName}>{c.authorName.split(' ')[0]}</Text>
                  <Text style={s.commentTime}>{relativeTime(c.createdAt)}</Text>
                </View>
                <Text style={s.commentBody}>{c.body}</Text>
              </View>
            </View>
          ))}

          {commentsOpen ? (
            <View style={s.replyRow}>
              <TextInput
                style={s.replyInput}
                value={reply}
                onChangeText={setReply}
                placeholder="Write a reply…"
                placeholderTextColor={Colors.textTertiary}
                multiline
                accessibilityLabel="Write a reply"
              />
              <Pressable
                onPress={() => {
                  if (!reply.trim()) return;
                  onComment(reply.trim());
                  setReply('');
                }}
                disabled={!reply.trim()}
                accessibilityRole="button"
                accessibilityLabel="Send reply"
                style={[s.replyBtn, !reply.trim() && { backgroundColor: Colors.textTertiary }]}
              >
                <Ionicons name="arrow-up" size={16} color={Colors.textOnBrown} />
              </Pressable>
            </View>
          ) : null}
        </View>
      ) : null}
    </Card>
  );
}

// ── Composer ────────────────────────────────────────────────

function Composer({
  visible, onClose, onSave, pncName, ctx,
}: {
  visible: boolean;
  onClose: () => void;
  onSave: (input: { category: NoteCategory; trend: Trend; title: string; body: string }) => void;
  pncName: string;
  ctx: ReturnType<typeof useCareContext>;
}) {
  const [category, setCategory] = useState<NoteCategory>('general');
  const [trend, setTrend] = useState<Trend>('same');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [tidying, setTidying] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reset = () => {
    setCategory('general'); setTrend('same'); setTitle(''); setBody('');
    setError(null); setTidying(false);
  };

  const tidy = async () => {
    if (body.trim().length < 10) return;
    setTidying(true);
    setError(null);
    try {
      const polished = await polishNote(body, ctx);
      setTitle(polished.title);
      setBody(polished.body);
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setTidying(false);
    }
  };

  const save = () => {
    if (!body.trim()) return;
    onSave({
      category,
      trend,
      title: title.trim() || body.trim().split(/[.!?]/)[0].slice(0, 60),
      body: body.trim(),
    });
    reset();
  };

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <SafeAreaView style={s.modalSafe}>
        <View style={s.modalHeader}>
          <Pressable onPress={() => { reset(); onClose(); }} hitSlop={10} accessibilityRole="button">
            <Text style={s.modalCancel}>Cancel</Text>
          </Pressable>
          <Text style={s.modalTitle}>New note</Text>
          <Pressable onPress={save} disabled={!body.trim()} hitSlop={10} accessibilityRole="button">
            <Text style={[s.modalSave, !body.trim() && { color: Colors.textTertiary }]}>Save</Text>
          </Pressable>
        </View>

        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView contentContainerStyle={s.modalScroll} keyboardShouldPersistTaps="handled">
            <Field label={`How is ${pncName} compared with before?`}>
              <Segmented
                options={TRENDS.map(t => ({ value: t.value, label: t.label }))}
                value={trend}
                onChange={v => setTrend(v as Trend)}
              />
              <Text style={s.trendHint}>
                {trend === 'worse' || trend === 'urgent'
                  ? 'This will be flagged on the family’s home screen.'
                  : 'Used to build the trend the family sees.'}
              </Text>
            </Field>

            <Field label="What is this about?">
              <View style={s.chipWrap}>
                {CATEGORIES.map(c => (
                  <Chip
                    key={c.value}
                    label={c.label}
                    icon={c.icon as React.ComponentProps<typeof Ionicons>['name']}
                    selected={category === c.value}
                    onPress={() => setCategory(c.value)}
                  />
                ))}
              </View>
            </Field>

            <Field label="What happened?" hint="Write it however it comes out. You can tidy it up after." required>
              <Input
                value={body}
                onChangeText={setBody}
                multiline
                style={{ minHeight: 140 }}
                placeholder={`e.g. ${pncName} only drank about 500ml today, kept saying not thirsty. Tried coconut water, took that better.`}
              />
            </Field>

            <Button
              label={tidying ? 'Tidying…' : 'Tidy up with Cura AI'}
              variant="secondary"
              icon="chatbox-ellipses-outline"
              size="sm"
              loading={tidying}
              disabled={body.trim().length < 10}
              onPress={tidy}
            />
            {error ? <Text style={s.error}>{error}</Text> : null}

            <Field label="Title" hint="A short line the family sees first.">
              <Input value={title} onChangeText={setTitle} placeholder="Drinking less for the third day" />
            </Field>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Modal>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.bgBase },

  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: Spacing.md, paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  headerTitle: { ...Type.title, fontSize: 22, color: Colors.textStrong },
  headerSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },
  addBtn: {
    width: 40, height: 40, borderRadius: 20, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },

  filterBar: { paddingHorizontal: Spacing.md, paddingVertical: 10 },
  scroll: { paddingHorizontal: Spacing.md, gap: Spacing.sm },

  note: { gap: 10, overflow: 'hidden' },
  trendStripe: { position: 'absolute', left: 0, top: 0, bottom: 0, width: 4 },
  noteHead: { flexDirection: 'row', alignItems: 'flex-start', gap: 10, paddingLeft: 4 },
  catIcon: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  noteTitle: { ...Type.subhead, color: Colors.textStrong, lineHeight: 21 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 4, flexWrap: 'wrap' },
  metaText: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  dot: { color: Colors.textTertiary, fontSize: 11 },
  noteBody: { ...Type.body, fontSize: 14, color: Colors.textPrimary, lineHeight: 21, paddingLeft: 4 },

  noteActions: { flexDirection: 'row', gap: Spacing.sm, paddingLeft: 4 },
  action: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    paddingHorizontal: 11, paddingVertical: 6, borderRadius: Radius.pill,
    backgroundColor: Colors.surfaceTinted,
  },
  actionActive: { backgroundColor: Colors.brown },
  actionText: { fontSize: 12, fontWeight: '600', color: Colors.brown },

  comments: {
    gap: 10, paddingTop: 10, paddingLeft: 4,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
  },
  comment: { flexDirection: 'row', gap: 9, alignItems: 'flex-start' },
  commentHead: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  commentName: { ...Type.caption, color: Colors.textStrong, fontWeight: '700' },
  commentTime: { fontSize: 10.5, color: Colors.textTertiary },
  commentBody: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400', lineHeight: 19, marginTop: 2 },

  replyRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 8 },
  replyInput: {
    flex: 1, backgroundColor: Colors.surfaceRaised,
    borderWidth: 1, borderColor: Colors.border, borderRadius: Radius.lg,
    paddingHorizontal: 12, paddingVertical: 9, fontSize: 14, color: Colors.textStrong,
    maxHeight: 90,
  },
  replyBtn: {
    width: 32, height: 32, borderRadius: 16, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },

  modalSafe: { flex: 1, backgroundColor: Colors.bgBase },
  modalHeader: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Spacing.md, paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  modalTitle: { ...Type.subhead, color: Colors.textStrong },
  modalCancel: { ...Type.callout, color: Colors.textSecondary },
  modalSave: { ...Type.callout, color: Colors.brown, fontWeight: '700' },
  modalScroll: { padding: Spacing.md, gap: Spacing.md, paddingBottom: Spacing.xxl },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  trendHint: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', marginTop: 6 },
  error: { ...Type.caption, color: Colors.urgent, fontWeight: '500' },
});
